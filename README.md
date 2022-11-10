# ⚛️  Protomodule - DevOps Tools

[![License](https://img.shields.io/badge/license-Apache%202-blue.svg?style=flat)](https://github.com/protomodule/ops/blob/master/LICENSE)

**🚨 This library is under heavy development. Do not use in production code yet. 🚨**

## Installation 
not required

## Usage
### CLI

```
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/protomodule/ops/main/helpers/generate-version.sh)" -- -j version
```

## Project setup

This repo also contains templates for setting up a new dockerized project. All projects are containerized for deployment. A `Dockerfile` is copied, stored and modified in each project repo.

## Initialize web/frontend projects

Download templates by running:

```
curl -o Dockerfile https://raw.githubusercontent.com/protomodule/ops/main/templates/docker/Dockerfile.web
curl -o .dockerignore https://raw.githubusercontent.com/protomodule/ops/main/templates/docker/dockerignore.web
```

The newly added files should be checked into source control. Feel free to modify the files as needed.

## License

This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE) file.
