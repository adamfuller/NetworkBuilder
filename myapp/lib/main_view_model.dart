part of app;

class MainViewModel {
  //
  // Private members
  //
  List<StreamSubscription> _listeners;

  //
  // Public Properties
  //
  Function onDataChanged;
  bool isLoading = true;
  int layerCount = 0;
  Network network;
  Timer trainingTimer = Timer(Duration(seconds: 0), (){})..cancel();
  // bool isTraining = false;
  Color copyOutputColor = Colors.black;
  String copyJsonButtonText = "Network";
  String copyMatrixButtonText = "Matrix";
  TextEditingController networkInputsController = TextEditingController();
  TextEditingController networkOutputsController = TextEditingController();
  List<List<double>> inputsFromText;
  List<List<double>> outputsFromText;
  List<List<double>> testOutputs;
  List<int> layers = List<int>();
  String _testOutputString;
  bool isValidTrainingData = true;

  //
  // Getters
  //

  String get testOutputString {
    if (testOutputs.isEmpty) return "Empty";
    if (_testOutputString != null) return _testOutputString;

    _testOutputString = testOutputs?.fold<String>("", (s, output) {
      s += "[";
      for (int i = 0; i < output.length; i++) {
        s += "${output[i]}";
        if (i < output.length - 1) s += ",";
      }
      s += "]";
      s += "\n";
      return s;
    });

    return _testOutputString;
  }

  //
  // Constructor
  //
  MainViewModel(this.onDataChanged) {
    init();
  }

  //
  // Public functions
  //
  void init() async {
    if (_listeners == null) _attachListeners();

    //
    // Write any initializing code here
    //
    inputsFromText = List<List<double>>();
    testOutputs = List<List<double>>();
    // Assign test inputs
    networkInputsController ??= TextEditingController();
    networkInputsController.text = "0, 0, 0\n0, 0, 1\n0, 1, 0\n0, 1, 1\n1, 0, 0\n1, 0, 1\n1, 1, 0\n1, 1, 1\n";

    // Assign test outputs
    networkOutputsController ??= TextEditingController();
    networkOutputsController.text = "0\n1\n1\n0\n1\n0\n0\n0\n";

    // Parse the text from networkInputsController
    layers = [3, 8, 5, 8, 1];
    updateTrainingData();

    this.trainingTimer?.cancel();
    // isTraining = false;

    _assignNetwork();

    this.isLoading = false;
    onDataChanged();
  }

  void networkOutputsChanged(String s) => updateTrainingData();
  void networkInputsChanged(String s) => updateTrainingData();

  void _assignNetwork() {
    this.network = Network(
      layers,
      activationFunction: ActivationFunction.tanh,
    );
  }

  void resetNetwork() {
    network.reset();
    onDataChanged();
  }

  void savePressed() {
    Clipboard.setData(ClipboardData(text: network.prettyJsonString));
    copyJsonButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyJsonButtonText = "Network";
      onDataChanged();
    });
  }

  void saveMatrixPressed() {
    Clipboard.setData(ClipboardData(text: network.matrixString));
    copyMatrixButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyMatrixButtonText = "Matrix";
      onDataChanged();
    });
  }

  void toggleTraining() {
    onDataChanged();
    if (!trainingTimer.isActive) {
      trainingTimer = Timer.periodic(Duration(milliseconds: 100), (t) {
        _testOutputString = null;
        testOutputs.clear();
        for (int j = 0; j < outputsFromText.length; j++) {
          testOutputs.add(this.network.forwardPropagation(inputsFromText[j]));
          this.network.backPropagation(outputsFromText[j]);
        }
        onDataChanged();
      });
    } else {
      trainingTimer.cancel();
    }
  }

  void testPressed() {
    _testOutputString = null;
    // Check if the data is there
    if (inputsFromText.isEmpty) updateTrainingData();
    testOutputs.clear();
    for (List<double> input in inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }
    onDataChanged();
  }

  //
  // Private functions
  //
  void _attachListeners() {
    if (this._listeners == null) {
      this._listeners = [
        //
        // Put listeners here
        //
      ];
    }
  }

  //
  // Dispose
  //
  void dispose() {
    this._listeners?.forEach((_) => _.cancel());
    this.networkInputsController.dispose();
    this.networkOutputsController.dispose();
  }

  

  void updateTrainingData() {
    // Make sure there is some data
    if (networkInputsController.text.isEmpty) {
      isValidTrainingData = false;
      onDataChanged();
      return;
    }
    if (networkOutputsController.text.isEmpty) {
      isValidTrainingData = false;
      onDataChanged();
      return;
    }

    // Update inputs
    List<List<double>> parsedInputs = _parseDoubleList(networkInputsController.text);

    // Update expected outputs
    List<List<double>> parsedOutputs = _parseDoubleList(networkOutputsController.text);

    // if any are null or they don't match they aren't valid
    if (parsedInputs == null || parsedOutputs == null || parsedInputs?.length != parsedOutputs?.length) {
      isValidTrainingData = false;
      onDataChanged();
      return;
    }

    // Make sure all internal lengths match
    for (int i = 0; i < parsedInputs.length - 1; i++) {
      if (parsedInputs[i].length != parsedInputs[i + 1].length) {
        isValidTrainingData = false;
        onDataChanged();
        return;
      }
      if (parsedOutputs[i].length != parsedOutputs[i + 1].length) {
        isValidTrainingData = false;
        onDataChanged();
        return;
      }
    }

    inputsFromText = parsedInputs;
    outputsFromText = parsedOutputs;

    // bool shouldReassign = false;
    if (layers.last != outputsFromText[0].length) {
      layers.last = outputsFromText[0].length;
      network.layers.last.resize(outputsFromText[0].length);
      // shouldReassign = true;
    }
    if (layers[0] != inputsFromText[0].length) {
      layers[0] = inputsFromText[0].length;
      // shouldReassign = true;
    }

    isValidTrainingData = true;
    onDataChanged();
  }

  List<List<double>> _parseDoubleList(String text) {
    List<List<double>> _output = List<List<double>>();
    if (text.isEmpty) return null;
    List<String> lines = text.split("\n").where((l) => l.isNotEmpty).toList();
    for (String s in lines) {
      _output.add(List<double>());
      List<String> elements = s.split(",").where((l) => l.isNotEmpty).toList();
      elements.forEach(
        (e) => _output.last.add(
          double.tryParse(e),
        ),
      );
      // cancel if any wasn't able to be parsed
      if (_output.last.any((e) => e == null)) return null;
    }

    return _output;
  }
}
