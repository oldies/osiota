const fs = require("fs");
const { decryptSops } = require("sops-age");

// helper:
exports.read = function(config_file) {
	if (!config_file) {
		return {};
	}
	try {
		let contents = fs.readFileSync(config_file);
		contents = contents.toString().replace(/^#.*\n/, "");
		let parsed;
		try {
			parsed = JSON.parse(contents);
		} catch (e) {
			throw new Error("Invalid JSON: " + e.message);
		}
		if (parsed.sops) {
			// Only decrypt if sops key is present
			return decryptSops(contents, { fileType: "json" });
		} else {
			return parsed;
		}
	} catch (err) {
		throw new Error('Error reading config file', { cause: err });
	}
	return {};
};
exports.write = function(config_file, config) {
	fs.writeFile(config_file,
			JSON.stringify(config, null, '\t')+"\n",
			function(err) {
			if (err) {
				throw err;
			}
	});
};
