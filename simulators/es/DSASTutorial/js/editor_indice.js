const fs = require("fs");
const readline = require("readline");

// Ruta a tu fichero HelpNDoc
const RUTA = "C:/GITS/Tutoriales/Trabajo/Spanish/DSASTutorial/js/hndsd.js";

// Leer fichero
const contenido = fs.readFileSync(RUTA, "utf8");

// Extraer objeto hndsd
const match = contenido.match(/var hndsd\s*=\s*(\{[\s\S]*?\});/);
if (!match) {
    console.error("No se encontró el objeto hndsd en hndsd.js");
    process.exit(1);
}

let diccionario = eval("(" + match[1] + ")");

// Interfaz interactiva
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function menu() {
    console.log("\n=== Editor interactivo del índice HelpNDoc ===");
    console.log("1. Listar todas las palabras");
    console.log("2. Buscar palabra");
    console.log("3. Borrar palabra completa");
    console.log("4. Borrar un ID asociado a una palabra");
    console.log("5. Guardar cambios en hndsd.js");
    console.log("6. Salir");
    rl.question("Elige opción: ", opcion => {
        switch (opcion.trim()) {
            case "1": listarPalabras(); break;
            case "2": buscarPalabra(); break;
            case "3": borrarPalabra(); break;
            case "4": borrarID(); break;
            case "5": guardar(); break;
            case "6": rl.close(); break;
            default: menu(); break;
        }
    });
}

function listarPalabras() {
    console.log("\nPalabras indexadas:");
    console.log(Object.keys(diccionario).join(", "));
    menu();
}

function buscarPalabra() {
    rl.question("Introduce palabra a buscar: ", palabra => {
        if (diccionario[palabra]) {
            console.log(`\n${palabra} → IDs: ${diccionario[palabra].join(", ")}`);
        } else {
            console.log("\nNo existe esa palabra en el índice.");
        }
        menu();
    });
}

function borrarPalabra() {
    rl.question("Introduce palabra a borrar: ", palabra => {
        if (diccionario[palabra]) {
            delete diccionario[palabra];
            console.log(`\nPalabra '${palabra}' eliminada.`);
        } else {
            console.log("\nNo existe esa palabra.");
        }
        menu();
    });
}

function borrarID() {
    rl.question("Palabra: ", palabra => {
        if (!diccionario[palabra]) {
            console.log("No existe esa palabra.");
            return menu();
        }
        rl.question("ID a borrar: ", id => {
            id = parseInt(id);
            diccionario[palabra] = diccionario[palabra].filter(x => x !== id);
            console.log(`\nID ${id} eliminado de '${palabra}'.`);
            menu();
        });
    });
}

function guardar() {
    const nuevo = "var hndsd = " + JSON.stringify(diccionario) + ";";
    fs.writeFileSync(RUTA, nuevo);
    console.log("\nCambios guardados en hndsd.js");
    menu();
}

menu();