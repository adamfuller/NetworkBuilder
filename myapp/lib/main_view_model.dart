part of app;

class MainViewModel {
  //
  // Private members
  //
  List<StreamSubscription> _listeners;
  List<int> _layers = List<int>();
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
  TextEditingController networkInputsController = TextEditingController();
  TextEditingController networkOutputsController = TextEditingController();
  bool isValidTrainingData = true;

  //
  // Getters
  //

  String get testOutputString {
    if (network.testOutputs.isEmpty) return "Empty";

    return network.testOutputs?.fold<String>("", (s, output) {
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

    // Assign test outputs
    networkOutputsController ??= TextEditingController();
    networkOutputsController.text = "0\n1\n1\n0";

    // Parse the text from networkInputsController
    _layers = [2, 5, 4, 5, 1];
    _updateTrainingData();

    this._trainingTimer?.cancel();
    // isTraining = false;

    _assignNetwork();

    // Feed forward once to test the network
    testPressed();

    this.isLoading = false;
    onDataChanged();
  }

  void networkOutputsChanged(String s) => _updateTrainingData();
  void networkInputsChanged(String s) => _updateTrainingData();

  void _assignNetwork() {
    this.network = Network(
      [2, 5, 4, 5, 1], // Default for 3-bit XOR
      activationFunction: ActivationFunction.leakyRelu,
    );
  }

  /// Reset the networks weights, runCount, and error
  void resetNetwork() {
    network.reset();

    ///
    /// Copied from test pressed to run data through
    ///
    if (_inputsFromText.isEmpty) _updateTrainingData();
    network.testOutputs.clear();
    for (List<double> input in _inputsFromText) {
      network.testOutputs.add(network.forwardPropagation(input));
    }
    _feedSampleData();
  }

  void saveJsonPressed() {
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
    _toggleTimerTraining();
    onDataChanged();
  }

  void _webTimerFunction(Timer t) {
    network.testOutputs.clear();

    for (int j = 0; j < _outputsFromText.length; j++) {
      network.testOutputs.add(this.network.forwardPropagation(_inputsFromText[j]));
      this.network.backPropagation(_outputsFromText[j]);
    }

    onDataChanged();
  }

  void _timerFunction(Timer t) async {
    // Train the network and wait for result
    Network n = await Network.train(network, _inputsFromText, _outputsFromText);

    // If the training failed for whatever reason just exit
    if (n == null) return;

    // Reassign the current network
    network = n;

    network.testOutputs.clear();
    // Calculate the outputs
    for (List<double> input in _inputsFromText) {
      network.testOutputs.add(network.forwardPropagation(input));
    }

    onDataChanged();
  }

  void _toggleTimerTraining() {
    if (!_trainingTimer.isActive) {
      _trainingTimer = Timer.periodic(
        Duration(milliseconds: 30),
        kIsWeb ? _webTimerFunction : _timerFunction,
      );
    } else {
      _trainingTimer.cancel();
      onDataChanged();
    }
  }

  void testPressed() {
    // Check if the data is there
    if (_inputsFromText.isEmpty) _updateTrainingData();
    network.testOutputs.clear();
    for (List<double> input in _inputsFromText) {
      network.testOutputs.add(network.forwardPropagation(input));
    }
    onDataChanged();
  }

  void stepPressed() async {
    Network n = await Network.train(network, _inputsFromText, _outputsFromText);
    if (n == null) return;
    this.network = n;
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
    network.resizeLayer(updateIndex, newSize);

    _feedSampleData();
  }

  /// Remove a layer and pass test data through to resize
  void _removeLayer(int removeIndex) {
    network.removeLayer(removeIndex);

    _feedSampleData();
  }

  void _feedSampleData() {
    // Set sampleData count to weight of initial layer
    int sampleCount = network.layers[0].neurons[0].weights.length - 1;
    // Generate junk sample data
    List<double> sample = List.filled(sampleCount, 0.5);
    // Pass the sample data to correct weights
    network.forwardPropagation(sample);
    network.runCount = 0;

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

  void _updateTrainingData() {
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

    _inputsFromText = parsedInputs;
    _outputsFromText = parsedOutputs;

    if (_layers.last != _outputsFromText[0].length) {
      _layers.last = _outputsFromText[0].length;

      ///
      /// CONSIDER CHANGING LATER
      ///
      network.layers.last.resize(_outputsFromText[0].length);
    }
    if (_layers[0] != _inputsFromText[0].length) {
      _layers[0] = _inputsFromText[0].length;
    }

    isValidTrainingData = true;
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
    List<int> counts = network.hiddenLayerNeuronCount;
    counts.insert(insertIndex, neuronCount);

    // Insert a layer of size neuronCount with insertIndex Weights
    network.insetLayer(insertIndex, Layer(counts[insertIndex], neuronCount));

    _feedSampleData();
  }
}
