part of "network.dart";

class Layer {
  static const ActivationFunction defaultActivationFunction = ActivationFunction.leakyRelu;
  static Random r = Random();
  static double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));
  static double _sigmoidDerivative(double x) => _sigmoid(x) * (1.0 - _sigmoid(x));
  static double _sigmoidishDerivative(double x) => x * (1.0 - x);

  static double _tanh(double x) => (exp(x) - exp(-x)) / (exp(x) + exp(-x));
  static double _tanhDerivative(double x) => 1.0 - (x * x);

  static double _relu(double x) => x > 0.0 ? x : 0.0;
  static double _reluDerivative(double x) => x > 0.0 ? 1.0 : 0.0;

  static double _leakyRelu(double x) => x > 0.0 ? x : 0.1 * x;
  static double _leakyReluDerivative(double x) => x > 0.0 ? 1.0 : 0.1;

  // double _softplus(double x) => log(1 + exp(x));

  // double _softplusDerivative(double x) => 1.0 / (1.0 + exp(-x));

  // TODO: Make into array to allow per neuron activation functions
  double Function(double) _normalize = _leakyRelu;
  double Function(double) _normalizeDerivative = _leakyReluDerivative;

  List<double> _outputs = [];

  // Weights for the inputs
  List<List<double>> _weights;

  // Adjustments to the weights after back prop
  List<List<double>> weightAdj;

  List<double> _deltas;
  List<double> _inputs;
  double learningRate;

  // Current activation function being used by the layer
  ActivationFunction _activationFunction;

  /// Returns the current activation function
  ActivationFunction get activationFunction => _activationFunction;

  /// Returns a copy of the weights array
  List<List<double>> get weights => _weights.map((e) => e).toList();

  /// Returns a copy of the deltas array
  List<double> get deltas => _deltas.map((e) => e).toList();

  /// Update normalization and normalizationDerivative methods
  set activationFunction(ActivationFunction af) {
    _activationFunction = af;
    switch (af) {
      case ActivationFunction.leakyRelu:
        _normalize = _leakyRelu;
        _normalizeDerivative = _leakyReluDerivative;
        break;
      case ActivationFunction.relu:
        _normalize = _relu;
        _normalizeDerivative = _reluDerivative;
        break;
      case ActivationFunction.sigmoid:
        _normalize = _sigmoid;
        _normalizeDerivative = _sigmoidDerivative;
        break;
      case ActivationFunction.sigmoidish:
        _normalize = _sigmoid;
        _normalizeDerivative = _sigmoidishDerivative;
        break;
      case ActivationFunction.tanh:
        _normalize = _tanh;
        _normalizeDerivative = _tanhDerivative;
        break;
      default:
        _normalize = _leakyRelu;
        _normalizeDerivative = _leakyReluDerivative;
        break;
    }
  }

  Layer(
    int inputCount,
    int outputCount, {
    ActivationFunction activationFunction = Layer.defaultActivationFunction,
    this.learningRate = 0.033,
  }) {
    // Just make sure they aren't null
    _outputs = List<double>();
    _deltas = List<double>(outputCount);
    _inputs = List<double>();
    weightAdj = List<List<double>>();

    // Add a new list of weights for each neuron
    _weights = List<List<double>>();

    // set the activation function
    this.activationFunction = activationFunction;

    // Generate the weights
    for (int i = 0; i < outputCount; i++) {
      _weights.add(
        List.generate(
          inputCount + 1,
          (_) => (2.0 * Network.r.nextDouble() - 1.0),
        ),
      );
      this.weightAdj.add([]);
    }
  }

  // /// Changes the weights in each sublist to match inputSize
  void resizeInput(int inputSize) {
    if (inputSize >= _weights[0].length) {
      // Add some weights
      for (int i = 0; i < _weights.length; i++) {
        _weights[i].addAll(
          List.generate(
            inputSize - (_weights.last.length - 1),
            (index) => (2 * Network.r.nextDouble() - 1),
          ),
        );
      }
    } else {
      // reduce the weights
      for (int i = 0; i < _weights.length; i++) {
        // take one extra for bias
        _weights[i] = _weights[i].take(inputSize + 1).toList();
      }
    }
  }

  /// Changes the number of lists in weights to match outputSize
  void resizeOutput(int outputSize) {
    if (outputSize > _weights.length) {
      // Regenerate weights
      _weights = List.generate(
        outputSize,
        (index) => List.generate(
          _weights.last.length,
          (i) => (2 * Network.r.nextDouble() - 1),
        ),
      );
    } else {
      _weights = _weights.take(outputSize).toList();
      this.weightAdj = this.weightAdj.take(outputSize).toList();
    }
    weightAdj = List<List<double>>(outputSize);
    _deltas = List<double>(outputSize);
  }

  void randomize() {
    for (int i = 0; i < _weights.length; i++) {
      for (int j = 0; j < _weights[i].length; j++) {
        _weights[i][j] = (2 * Network.r.nextDouble() - 1);
      }
    }
  }

  List<double> forwardPropagation(List<double> inputData) {
    // inputData should NOT be used after here
    _inputs = [1.0].followedBy(inputData).toList();
    // Feed the input through the neurons
    _outputs = List<double>(_weights.length);
    double output;
    if (_inputs.length != _weights[0].length) {
      print("DATA DOESN'T MATCH");
    }
    for (int neuronIndex = 0; neuronIndex < _weights.length; neuronIndex++) {
      output = 0;

      for (int j = 0; j < _inputs.length; j++) {
        output += _inputs[j] * _weights[neuronIndex][j];
      }

      if (!output.isFinite) {
        print("OUTPUT is not finite");
      }

      _outputs[neuronIndex] = _normalize(output);
    }

    return _outputs;
  }

  void backPropagationOutput(List<double> expected) {
    double error;
    for (int neuronIndex = 0; neuronIndex < _weights.length; neuronIndex++) {
      // Difference between expected and calculated output
      error = _outputs[neuronIndex] - expected[neuronIndex];

      // Adjust for input based on error * gradient of normalized(output);
      _deltas[neuronIndex] = error * _normalizeDerivative(_outputs[neuronIndex]);

      if (!_deltas[neuronIndex].isFinite) {
        print("WARNING: Non-finite delta!");
      }

      // For each input calculate the new corresponding weight
      weightAdj[neuronIndex] = _inputs.map<double>((_i) => _i * _deltas[neuronIndex]).toList();
    }
    // print("D");
  }

  void backPropagationHidden(Layer nextLayer) {
    List<double> nextLayerDelta = nextLayer.deltas;

    for (int i = 0; i < _weights.length; i++) {
      _deltas[i] = 0;

      // Pulling each weight corresponding to this neuron in the layer
      for (int j = 0; j < nextLayer.weights.length; j++) {
        _deltas[i] += nextLayerDelta[j] * nextLayer.weights[j][i];
      }

      _deltas[i] *= _normalizeDerivative(_outputs[i]);

      weightAdj[i] = _inputs.map((_i) => _deltas[i] * _i).toList();
    }
    // print("d");
  }

  void updateWeights() {
    for (int neuronIndex = 0; neuronIndex < _weights.length; neuronIndex++) {
      for (int weightIndex = 0; weightIndex < _weights[neuronIndex].length; weightIndex++) {
        _weights[neuronIndex][weightIndex] -= (learningRate * weightAdj[neuronIndex][weightIndex]);
      }
    }
  }
}
