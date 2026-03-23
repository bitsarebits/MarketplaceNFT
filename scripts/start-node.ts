import { spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";

const metadataDir = path.join(process.cwd(), "metadata");

console.log("Starting local Hardhat node...");

// Spawn the hardhat node as a child process and pipe output to the current terminal
const nodeProcess = spawn("npx hardhat node", {
    stdio: "inherit",
    shell: true,
});

// Function to delete the entire metadata directory and exit
function cleanupAndExit() {
    console.log("\n\nShutdown signal received. Cleaning up...");

    if (fs.existsSync(metadataDir)) {
        // Removes the directory and all its contents directly
        fs.rmSync(metadataDir, { recursive: true, force: true });
        console.log("Metadata directory removed.");
    } else {
        console.log("No metadata directory found to clean.");
    }

    // Ensure the Hardhat node process is terminated
    if (!nodeProcess.killed) {
        nodeProcess.kill();
    }

    process.exit(0);
}

// Intercept SIGINT and SIGTERM
process.on("SIGINT", cleanupAndExit);
process.on("SIGTERM", cleanupAndExit);
