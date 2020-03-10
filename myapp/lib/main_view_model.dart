part of app;

class MainViewModel {
  static const String _e = "2.718281828459045235360287471352";
  static const Map<ActivationFunction, String> _activationFunctionPythonStrings = {
    ActivationFunction.leakyRelu: "lambda x: x if x > 0 else 0.1 * x",
    ActivationFunction.relu: "lambda x: x if x > 0 else 0",
    ActivationFunction.sigmoid: "lambda x: 1 / (1 + ($_e)**(-x)",
    ActivationFunction.sigmoidish: "lambda x: 1 / (1 + ($_e)**(-x)",
    ActivationFunction.tanh: "lambda x: (($_e)**x - ($_e)**(-x))/(($_e)**x + ($_e)**(-x))",
  };

  //
  // Private members
  //
  int _timerPeriod = 30;
  List<StreamSubscription> _listeners;
  List<List<double>> _inputsFromText;
  List<List<double>> _outputsFromText;
  Timer _trainingTimer = Timer(Duration(seconds: 0), () {})..cancel();

  //
  // Public Properties
  //
  Function onDataChanged;
  bool isLoading = true;
  Network network;
  // Color copyOutputColor = Colors.black;
  String copyJsonButtonText = "Network";
  String copyMatrixButtonText = "Matrix";
  String copyPythonButtonText = "Python";
  TextEditingController networkInputsController = TextEditingController();
  TextEditingController networkOutputsController = TextEditingController();
  bool isValidTrainingData = true;
  List<List<double>> testOutputs = List<List<double>>();
  int runCount = 0;
  // double avgError = 0.0;

  //
  // Getters
  //

  double get avgPercentError {
    double diffSum = 0;
    double expectedSum = 0;
    if (_outputsFromText.length != testOutputs.length) return 0.0;

    for (int i = 0; i < testOutputs.length; i++) {
      for (int j = 0; j < testOutputs[i].length; j++) {
        diffSum += (_outputsFromText[i][j] - testOutputs[i][j]).abs();
        expectedSum += _outputsFromText[i][j].abs();
      }
    }

    return (diffSum / expectedSum) * 100;
  }

  String get networkPythonFunction {
    String _norm = _activationFunctionPythonStrings[network.activationFunction];
    return "def feedForward(x):\n" +
        "    network = ${network.matrix.toString()}\n" +
        "    normalize = $_norm\n" +
        "    output = [1]\n" +
        "    output.extend(x)\n" +
        "    for layer in network:\n" +
        "        nextOutput = [1]\n" +
        "        for neuron in layer:\n" +
        "            neuronOutput = 0\n" +
        "            for i in range(len(output)):\n" +
        "                neuronOutput += neuron[i]*output[i]\n" +
        "            nextOutput.append(normalize(neuronOutput))\n" +
        "        output = nextOutput\n" +
        "    return output[1:]\n";
  }

  String get testOutputString {
    if (testOutputs.isEmpty) return "Empty";

    return testOutputs?.fold<String>("", (s, output) {
      s += "[";
      for (int i = 0; i < output.length; i++) {
        s += output[i].toStringAsFixed(6);
        if (i < output.length - 1) s += ",";
      }
      s += "]";
      s += "\n";
      return s;
    });
  }

  IconData get toggleTrainingIcon {
    return this._trainingTimer.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline;
  }

  bool get isTraining => this?._trainingTimer?.isActive ?? false;

  String get trainingDataValidityString => isValidTrainingData ? "(Valid)" : "(Invalid)";

  //
  // Constructor
  //
  MainViewModel(this.onDataChanged) {
    init();
  }

  // static Future<void> _sleep(int milliseconds) async => await Future.delayed(Duration(milliseconds: milliseconds), () => "");

  //
  // Public functions
  //
  void init() async {
    if (_listeners == null) _attachListeners();

    //
    // Write any initializing code here
    //
    _inputsFromText = List<List<double>>();
    // Assign test inputs
    networkInputsController ??= TextEditingController();
    networkInputsController.text = "0, 0\n0, 1\n1, 0\n1, 1\n";
    // networkInputsController.text = "0\n1\n";

    // Assign test outputs
    networkOutputsController ??= TextEditingController();
    networkOutputsController.text = "0\n1\n1\n0";
    // networkOutputsController.text = "0\n1\n";

    this._trainingTimer?.cancel();
    // isTraining = false;

    _assignNetwork();

    // Update both
    _updateTrainingData(wasInputs: true, wasOutputs: true);

    // Feed forward once to test the network
    testPressed();

    this.isLoading = false;
    onDataChanged();
  }

  void networkOutputsChanged(String s) => _updateTrainingData(wasOutputs: true);
  void networkInputsChanged(String s) => _updateTrainingData(wasInputs: true);

  void _assignNetwork() {
    this.network = Network(
      2,
      1,
      hiddenLayerSizes: [5, 4, 5], // Default for 3-bit XOR
      activationFunction: ActivationFunction.leakyRelu,
    );
  }

  /// Reset the networks weights, runCount, and error
  void resetNetwork() {
    network.reset();

    runCount = 0;

    ///
    /// Copied from test pressed to run data through
    ///
    if (_inputsFromText.isEmpty) _updateTrainingData();
    testOutputs.clear();
    for (List<double> input in _inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }
    _feedSampleData();
  }

  void saveJsonPressed() {
    String s = JsonEncoder.withIndent("    ").convert(network.toJson());
    Clipboard.setData(ClipboardData(text: s));
    copyJsonButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyJsonButtonText = "Network";
      onDataChanged();
    });
  }

  void savePythonPressed() {
    Clipboard.setData(ClipboardData(text: networkPythonFunction));
    copyPythonButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyPythonButtonText = "Python";
      onDataChanged();
    });
  }

  void saveMatrixPressed() {
    Clipboard.setData(ClipboardData(text: network.matrix.toString()));
    copyMatrixButtonText = "Copied";
    onDataChanged();
    Timer(Duration(seconds: 1), () {
      copyMatrixButtonText = "Matrix";
      onDataChanged();
    });
  }

  void toggleTraining() {
    _toggleTimerTraining();
    onDataChanged();
  }

  void _webTimerFunction(Timer t) {
    for (int j = 0; j < _outputsFromText.length; j++) {
      this.network.forwardPropagation(_inputsFromText[j]);
      this.network.backPropagation(_outputsFromText[j]);
    }

    testOutputs.clear();
    // Calculate the outputs
    for (List<double> input in _inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }

    onDataChanged();
  }

  void _timerFunction(Timer t) {
    // Train the network and wait for result
    /// TODO: Push training into Isolate
    // Network n = await Network.train(network, _inputsFromText, _outputsFromText);
    for (int i = 0; i < _inputsFromText.length; i++) {
      this.network.forwardPropagation(_inputsFromText[i]);
      this.network.backPropagation(_outputsFromText[i]);
    }
    runCount++;

    // If the training failed for whatever reason just exit
    // if (n == null) return;

    // Reassign the current network
    // network = n;

    testOutputs.clear();
    // Calculate the outputs
    for (List<double> input in _inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }

    onDataChanged();
  }

  void _toggleTimerTraining() {
    if (!_trainingTimer.isActive) {
      _trainingTimer = Timer.periodic(
        Duration(milliseconds: _timerPeriod),
        _timerFunction,
      );
    } else {
      _trainingTimer.cancel();
      onDataChanged();
    }
  }

  void testPressed() {
    // Check if the data is there
    if (_inputsFromText.isEmpty) _updateTrainingData();
    testOutputs.clear();
    for (List<double> input in _inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }
    onDataChanged();
  }

  void stepPressed() {
    // Network n = await Network.train(network, _inputsFromText, _outputsFromText);
    for (int i = 0; i < _inputsFromText.length; i++) {
      network.forwardPropagation(_inputsFromText[i]);
      network.backPropagation(_outputsFromText[i]);
    }

    testOutputs.clear();

    for (List<double> input in _inputsFromText) {
      testOutputs.add(network.forwardPropagation(input));
    }

    print(network.matrix);

    runCount++;
    // if (n == null) return;
    // this.network = n;
    onDataChanged();
  }

  /// Update the learning rate
  void learningRateChanged(double lr) {
    this.network.learningRate = lr;
    _feedSampleData();
  }

  /// Update the Activation Function
  void activationFunctionChanged(ActivationFunction av) {
    this.network.activationFunction = av;
    _feedSampleData();
  }

  /// Callback for long press on layer size indicator
  void removeLayerPressed(BuildContext context, index) async {
    bool shouldRemove = await showConfirmDialog(
      context,
      "Remove Layer",
      "Do you want to remove this layer?",
      confirmText: "Yes",
      denyText: "No",
    );
    if (shouldRemove ?? false) {
      int removeIndex = (index / 2).floor();
      // Stop training (if applicable) and remove the layer
      _removeLayer(removeIndex);
    }
  }

  void resizeLayerPressed(BuildContext context, int index) async {
    String nextSizeString = await showInputDialog(
      context,
      "Update layer size?",
      keyboardType: TextInputType.number,
      subtitle: "How many neurons should be in this layer?",
    );
    if (nextSizeString == null || nextSizeString.isEmpty) return;
    int newSize = int.tryParse(nextSizeString);
    if (newSize == null) return;

    int updateIndex = (index / 2).floor();

    _resizeLayer(updateIndex, newSize);
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

  /// Resize a layer and pass test data through to resize weights
  void _resizeLayer(int updateIndex, int newSize) {
    /// TODO: FIX THIS
    network.changeLayerSize(updateIndex, newSize);

    _feedSampleData();
  }

  /// Remove a layer and pass test data through to resize
  void _removeLayer(int removeIndex) {
    /// TODO: FIX THIS
    network.removeLayer(removeIndex);

    _feedSampleData();
  }

  void _feedSampleData() {
    // Set sampleData count to weight of initial layer
    int sampleCount = network.layers[0].weights[0].length - 1;
    // Generate junk sample data
    List<double> sample = List.filled(sampleCount, 0.5);
    // Pass the sample data to correct weights
    network.forwardPropagation(sample);
    // runCount = 0;

    onDataChanged();
  }

  List<List<double>> _parseDoubleList(String text) {
    // return null;
    // print(text.length);
    List<List<double>> _output = List<List<double>>();
    if (text.isEmpty) return null;
    List<String> lines = text.split("\n").where((l) => l.isNotEmpty).toList();
    for (String s in lines) {
      _output.add(List<double>());
      List<String> elements = s.split(",").where((l) => l.isNotEmpty).toList();
      elements.forEach(
        (e) => _output.last.add(
          double.parse(e),
        ),
      );
      // cancel if any wasn't able to be parsed
      if (_output.last.any((e) => e == null)) return null;
    }

    return _output;
  }

  void _updateTrainingData({
    bool wasInputs = false,
    bool wasOutputs = false,
  }) {
    isValidTrainingData = true;
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

    // Update inputs if the data changed was the inputs
    List<List<double>> parsedInputs = wasInputs ? _parseDoubleList(networkInputsController.text) : _inputsFromText;

    // Update expected outputs if the data changed was the outputs
    List<List<double>> parsedOutputs = wasOutputs ? _parseDoubleList(networkOutputsController.text) : _outputsFromText;

    // if any are null or they don't match they aren't valid
    if (parsedInputs == null || parsedOutputs == null) {
      isValidTrainingData = false;
      // onDataChanged();
      // return;
    }

    // Make sure all internal lengths match
    if (parsedInputs.length == parsedOutputs.length) {
      for (int i = 0; i < parsedInputs.length - 1; i++) {
        if (parsedInputs[i].length != parsedInputs[i + 1].length) {
          isValidTrainingData = false;
          // onDataChanged();
          // return;
        }
        if (parsedOutputs[i].length != parsedOutputs[i + 1].length) {
          isValidTrainingData = false;
          // onDataChanged();
          // return;
        }
      }
    }

    if (wasInputs && isValidTrainingData) _inputsFromText = parsedInputs;
    if (wasOutputs && isValidTrainingData) _outputsFromText = parsedOutputs;

    if (wasOutputs && isValidTrainingData && network.layers.last.weights.length != _outputsFromText[0].length) {
      ///
      /// CONSIDER CHANGING LATER
      ///
      network.layers.last.resizeOutput(_outputsFromText[0].length);
    }

    if (wasInputs && isValidTrainingData && network.layers[0].weights[0].length != _inputsFromText[0].length) {
      network.layers[0].resizeInput(_inputsFromText[0].length);
    }

    onDataChanged();
  }

  //
  // Dispose
  //
  void dispose() {
    this._listeners?.forEach((_) => _.cancel());
    this.networkInputsController.dispose();
    this.networkOutputsController.dispose();
  }

  void addLayerPressed(BuildContext context, int index) async {
    String neuronCountString = await showInputDialog(
      context,
      "Add new layer?",
      subtitle: "This will reset the current network.",
      hintText: "How many neurons?",
      keyboardType: TextInputType.number,
    );
    if (neuronCountString == null) return;
    int neuronCount = int.tryParse(neuronCountString);
    if (neuronCount == null) return;

    int insertIndex = (index / 2).floor();

    // Insert a layer of size neuronCount with insertIndex Weights
    network.insertLayer(insertIndex, neuronCount);

    _feedSampleData();
  }

  void loadInputsFromFile() async {
    File f = await FilePicker.getFile(fileExtension: ".csv");
    f.readAsString().then((text) {
      networkInputsController.text = text;
      // _updateTrainingData(wasInputs: true);
      onDataChanged();
    });
  }

  void loadOutputsFromFile() async {
    File f = await FilePicker.getFile(fileExtension: ".csv");
    f.readAsString().then((text) {
      networkOutputsController.text = text;
      onDataChanged();
      // _updateTrainingData(wasOutputs: true);
    });
  }
}
