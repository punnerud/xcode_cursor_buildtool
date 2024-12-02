# Xcode Cursor Build Tool

![Build Tool Demo](https://raw.githubusercontent.com/punnerud/xcode_cursor_buildtool/main/assets/build.png)

A specialized build script designed to integrate with Cursor AI for Xcode project builds, providing intelligent error reporting through the Cursor terminal.

## Overview

This tool serves as a bridge between Cursor AI and Xcode projects, offering automated build processes with detailed error feedback directly in your Cursor terminal.

## Features

- 🔍 Automatic Xcode scheme detection
- 📱 Smart iOS simulator selection and management
- 🔄 Intelligent build system with fallback mechanisms
- ⚠️ Real-time error reporting in Cursor terminal
- 🧹 Automatic clean build on initial failure

## Integration with Cursor AI

1. Add the build script to your Xcode project:
   - Copy `build.sh` to your project root
   - Ensure it's tracked in version control

2. Configure in Cursor AI:
   ```json
   {
     "build": {
       "command": "./build.sh",
       "path": "${workspaceFolder}"
     }
   }
   ```

## Usage

1. In Cursor AI, trigger builds using:
   - Command Palette: `Build Project`
   - Keyboard Shortcut: [Your preferred shortcut]

2. View Results:
   - Build progress appears in Cursor terminal
   - Errors and warnings are highlighted inline
   - Click on errors to jump to relevant code

## Error Reporting

The script provides detailed error feedback in the Cursor terminal:

- Build failures with source location
- Compiler warnings with context
- Simulator and environment issues
- Runtime configuration problems

## Prerequisites

- macOS
- Xcode installed in `/Applications`
- Command Line Tools for Xcode
- Cursor AI editor

## Troubleshooting

Common issues and solutions:

- **Build Script Permissions**: Ensure the script is executable
  ```bash
  chmod +x build.sh
  ```
- **Xcode Configuration**: Verify Xcode path and selected scheme
- **Simulator Issues**: Check available simulators in Xcode

## Contributing

Feel free to submit issues and pull requests to improve the integration between Cursor AI and Xcode builds.
