const http = require("http");
const fs = require("fs/promises");
const { decryptSops } = require("sops-age");

const configuration_files = {};

exports.init = async function(node, app_config, main, host_info) {
	if (typeof app_config.file !== "string") {
		console.warn("config-include: No filename given.");
		return;
	}
	if (app_config.once && typeof configuration_files[app_config.file]
			!== "undefined") {
		console.log("config-include: Configuration file already "+
				"loaded.");
		return;
	}
	configuration_files[app_config.file] = this;

	if (typeof app_config.writeable !== "boolean") {
		app_config.writeable = false;
	}

	let config = {};
	let sub_apps = [];
	try {
		console.warn("app_config.file", app_config.file);
		const content = await fs.readFile(app_config.file);
		let configRaw = content.toString();
		console.warn("configRaw", configRaw);
		try {
			// Try to decrypt as SOPS-age encrypted file
			const decrypted = await decryptSops(configRaw, { fileType: "json" });
			console.warn("decrypted", decrypted);
			if (decrypted && typeof decrypted === "object" && decrypted.sops === undefined) {
				config = decrypted;
			} else {
				config = JSON.parse(configRaw);
			}
		} catch (e) {
			// Not a SOPS file or decryption failed, fallback to plain JSON
			console.warn("Not a SOPS file or decryption failed, fallback to plain JSON", e);
			config = JSON.parse(configRaw);
		}
		config = main.config_cleaning(config);
		sub_apps = main.sub_config(config, this._source);
	} catch (e) {
		if (!app_config.ignore_missing)
			console.warn("Include Config, Exception", e.stack || e);
	}

	const cleaning_object = [];
	if (app_config.writeable && app_config.file.match(/\.json$/i)) {
		const cb_config_save = async function() {
			try {
				await fs.writeFile(app_config.file,
					JSON.stringify(config, null, '\t'));
			} catch (err) {
				console.error("Error writing file:", err);
			}
		};
		main.on("config_save", cb_config_save);
		cleaning_object.push(() => {
			main.removeListener("config_save", cb_config_save);
		});
	}

	cleaning_object.push(() => {
		configuration_files[app_config.file] = undefined;
	});

	cleaning_object.push(await sub_apps);

	// undo sub_config
	return cleaning_object;
};
