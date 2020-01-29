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
  Timer trainingTimer;
  bool isTraining = false;
  String copyButtonText = "Copy";
  String copyJsonButtonText = "Copy Network";
  TextEditingController networkInputsController = TextEditingController();
  TextEditingController networkOutputsController = TextEditingController();
  List<List<double>> inputsFromText;
  List<List<double>> outputsFromText;
  List<List<double>> testOutputs;
  List<int> layers = List<int>();
  String _testOutputString;

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
    isTraining = false;

    _assignNetwork();

    this.isLoading = false;
    onDataChanged();
  }

  void _assignNetwork() {
    this.network = Network(
      layers,
      activationFunction: ActivationFunction.softplus,
    );
  }

  void resetNetwork() {
    network.timesRun = 0;
    for (Layer layer in network.layers) {
      for (Neuron neuron in layer.neurons) {
        neuron.reset();
      }
    }
    onDataChanged();
  }

  void savePressed() {
    Clipboard.setData(ClipboardData(text: network.prettyJsonString));
    copyJsonButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyJsonButtonText = "Copy Network";
      onDataChanged();
    });
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

  void outputPressed() {
    print(this.network.feedForward([0, 1, 0]));
  }

  void toggleTraining() {
    isTraining = !isTraining;
    onDataChanged();
    if (isTraining) {
      trainingTimer = Timer.periodic(Duration(milliseconds: 100), (t) {
        _testOutputString = null;
        testOutputs.clear();
        for (int j = 0; j < outputsFromText.length; j++) {
          testOutputs.add(this.network.feedForward(inputsFromText[j]));
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
      testOutputs.add(network.feedForward(input));
    }
    onDataChanged();
  }

  void updateTrainingData() {
    // Make sure there is some data
    if (networkInputsController.text.isEmpty) return;
    if (networkOutputsController.text.isEmpty) return;

    // Update inputs
    inputsFromText?.clear();
    inputsFromText = _parseDoubleList(networkInputsController.text);

    // Update expected outputs
    outputsFromText?.clear();
    outputsFromText = _parseDoubleList(networkOutputsController.text);
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

    // if (shouldReassign) _assignNetwork();

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
    }
    return _output;
  }

  void networkOutputsChanged(String s) {
    // print(s);
    onDataChanged();
  }

  /// Not really used yet?
  void networkInputsChanged(String s) {
    // print(s);
    onDataChanged();
  }
}
