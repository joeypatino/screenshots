## Screenshots

This bash script automates the extraction of screenshots from an Xcode test result (.xcresult) package. It requires the [xcparse](https://github.com/ChargePoint/xcparse) tool, which is used to extract the screenshots.

### Requirements
- [xcparse](https://github.com/ChargePoint/xcparse)
- Bash shell

### Usage

Runs unit tests and extracts captured images to the ./screenshots directory relative to the Xcode project or workspace.

```bash
$ ./screenshots.sh --argument <Options>

  --project  The name of the Xcode project.
  --workspace  The name of the Xcode workspace.
  --scheme  The project scheme to build.
  --testLanguage  The language to run the simulator/unit tests in.
  --argument  A command line argument that will be passed directly to your unit tests. You should wrap the argument in quotes. You may pass as many arguments as needed.
  --usage  Prints usage information.
```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joeypatino/screenshots. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the Contributor Covenant code of conduct.

### Meta

Joey Patino – @nsinvalidarg – joey.patino@pm.me

### License

screenshots is available as open source under the terms of the MIT License.
