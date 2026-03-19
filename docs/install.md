# taq kdb-x installation

## Dependencies

* Logging: The module generates status and error logs. By default, it utilizes the KX Logging framework. If a custom logger is not provided via the configuration parameters, ensure the [KX logging](https://code.kx.com/kdb-x/modules/logging/overview.html) is installed and available in your [QPATH](https://code.kx.com/kdb-x/modules/module-framework/quickstart.html#search-path). You can install `logging` and `printf` by

```bash
LATEST=$(curl -s https://api.github.com/repos/KxSystems/logging/releases/latest | grep 'tag_name' | cut -d '"' -f 4) \
curl -L https://github.com/KxSystems/logging/archive/refs/tags/$LATEST.zip -o logging.zip && \
unzip -j logging.zip "logging-$LATEST/log.q" -d $HOME/.kx/mod/kx/ && \
rm logging.zip
LATEST=$(curl -s https://api.github.com/repos/KxSystems/printf/releases/latest | grep 'tag_name' | cut -d '"' -f 4) \
curl -L https://github.com/KxSystems/printf/archive/refs/tags/$LATEST.zip -o printf.zip && \
unzip -j printf.zip "printf-$LATEST/printf.q" -d $HOME/.kx/mod/kx/ && \
rm printf.zip
```

## Installation

[`taq.q`](../taq.q) is written as a module, under kdb-x's module framework. Though modules can be loaded from anywhere if added to your [`$QPATH`](https://code.kx.com/kdb-x/modules/module-framework/quickstart.html#search-path), we recommend installing to the `$HOME/.kx/mod/kx` folder. This is to avoid name clashes with other user defined modules, as well as providing a location for other KX modules to cross reference each other (e.g. the taq module references `..logging`)

```bash
export QPATH="$QPATH:$HOME/.kx/mod"
mkdir -p ~/.kx/mod/kx/
cp -r taq ~/.kx/mod/kx/
```

Add the export statement to your `bashrc` or equivalent to persist across sessions.

Now from anywhere you can import the taq library

```q
q)([parseToDisk]): taq:use`kx.taq;
```

See [reference.md](reference.md) to learn how to use the module.
