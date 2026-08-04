const fs = require("fs");
const path = require("path");

const PROJECT_FILE = "default.project.json";
const FEATURES_DIR = path.join("src", "features");

const project = {
  name: "Mounts",
  tree: {
    $className: "DataModel",

    ReplicatedStorage: {
      Shared: { $path: "src/shared" },
      Packages: { $path: "Packages" },
      // Modelos .rbxm/.rbxmx sueltos (sin código), compartidos por ambos places.
      // Cualquier archivo que se meta en la carpeta RojoShared/ del repo aparece
      // aquí tal cual — Rojo lo sincroniza igual que un script.
      RojoShared: { $path: "RojoShared" },
    },

    ServerScriptService: {
      Server: { $path: "src/server" },
      ServerPackages: { $path: "ServerPackages" },
    },

    StarterPlayer: {
      StarterPlayerScripts: {
        Client: { $path: "src/client" },
      },
    },
  },
};

const features = fs.existsSync(FEATURES_DIR)
  ? fs.readdirSync(FEATURES_DIR, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
  : [];

for (const feature of features) {
  const base = `src/features/${feature}`;

  if (fs.existsSync(path.join(FEATURES_DIR, feature, "shared"))) {
    project.tree.ReplicatedStorage[feature] = { $path: `${base}/shared` };
  }

  if (fs.existsSync(path.join(FEATURES_DIR, feature, "server"))) {
    project.tree.ServerScriptService[feature] = { $path: `${base}/server` };
  }

  if (fs.existsSync(path.join(FEATURES_DIR, feature, "client"))) {
    project.tree.StarterPlayer.StarterPlayerScripts[feature] = { $path: `${base}/client` };
  }
}

fs.writeFileSync(PROJECT_FILE, JSON.stringify(project, null, 2));

console.log("default.project.json actualizado.");

if (features.length > 0) {
  console.log(`Features detectados: ${features.join(", ")}`);
} else {
  console.log("No se encontraron features en src/features/");
}
