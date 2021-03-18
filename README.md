### Screenshots
This script requires [xcparse](https://github.com/ChargePoint/xcparse) in order to extract the screenshots from the `.xcresult` package.

```
Info:

     Runs Unit tests and extracts any captured images to the ./screenshots directory, relative to the xcode project or workspace.

Usage:

     $./screenshots.sh --argument CommandLineArgument

Options:

    --project		 The name of the Xcode project

    --workspace		 The name of the Xcode workspace

    --scheme		 the project Scheme to build

    --argument		 Command line argument that will be passed directly to your Unit tests.
        		 You should wrap the argument in quotes. You may pass as many arguments as needed.

    --testLanguage	 the language to run the simulator / unit tests in.

    --usage		 Prints this usage information
```
