# OpenEdge Demo Project

The OpenEdge Demo project is a user-friendly way to create and manage Instance Groups within a network environment. Built to support modern cloud infrastructures, this project features an interactive bash script with syntax highlighting and easy Kubernetes integration.

## Table of Contents

1. [Features](#features)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Contributing](#contributing)
6. [License](#license)

## Features

- **Interactive Instance Management**: Create, modify, and connect to instances with simple command-line prompts.
- **Syntax Highlighting**: Readable YAML content output with colored syntax.
- **Kubernetes Integration**: Utilize Kubernetes commands to manage instances seamlessly.

## Prerequisites

- Python (3.x recommended)
- Pygments (`pip install Pygments`)
- Kubernetes CLI (`kubectl`)

## Installation

Clone the repository to your local machine:

\`\`\`bash
git clone https://github.com/ronbc78/OpenEdge-Demo.git
cd OpenEdge-Demo
\`\`\`

Make sure you have the prerequisites installed and properly configured.

## Usage

Run the script from the project directory:

\`\`\`bash
./create_instance_group.sh
\`\`\`

Follow the interactive prompts to configure your instance group, and the script will handle the rest. You will see the syntax-highlighted YAML output in your terminal.

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and submission process.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
