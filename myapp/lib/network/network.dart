library neural_network;

import 'dart:math';

part 'layer.dart';

// const double _defaultLearningRate = 0.033;
// const ActivationFunction _defaultActivationFunction = ActivationFunction.sigmoid;

class Network {
  //
  // Private static
  //

  //
  // Public static
  //
  static Random r = Random();

  //
  // Private fields
  //

  //
  // Public fields
  //
  List<Layer> layers;

  /// Gets the first learning rate
  double get learningRate => this.layers.first.learningRate;

  ActivationFunction get activationFunction => this.layers.first.activationFunction;

  /// Returns an array representing the network
  List<List<List<double>>> get matrix => this.layers.map((e) => e.weights).toList();

  //
  // Setters
  //

  /// Sets all layer activation functions
  set activationFunction(ActivationFunction af) => this.layers.forEach((l) => l.activationFunction = af);

  /// Sets all layer learning rates
  set learningRate(double val) => this.layers.forEach((l) => l.learningRate = val);

  Network(
    int inputSize,
    int outputSize, {
    List<int> hiddenLayerSizes,
    ActivationFunction activationFunction = Layer.defaultActivationFunction,
    this.layers,
    double learningRate = 0.033,
  }) {
    // Set the layer sizes
    List<int> _hiddenLayerSizes = [inputSize].followedBy(hiddenLayerSizes ?? []).followedBy([outputSize]).toList();

    // Remove any zero or null values in case someone did dumb stuff
    _hiddenLayerSizes.removeWhere((n) => n == 0 || n == null);

    // Setup the layers
    layers ??= [];

    // Add any remaining hidden layers
    for (int i = 1; i < _hiddenLayerSizes.length; i++) {
      layers.add(Layer(
        _hiddenLayerSizes[i - 1],
        _hiddenLayerSizes[i],
        activationFunction: activationFunction,
        learningRate: learningRate,
      ));
    }
  }

  /// Returns a map representation of the network
  Map<String, dynamic> toJson() {
    return {"layers": matrix, "learningRate": learningRate, "activationFunction": activationFunctionStrings[layers.first.activationFunction]};
  }

  void reset() {
    this.layers.forEach((l) => l.randomize());
  }

  void removeLayer(int index) {
    if (index > 0) {
      // The earlier layer will have to resize it's output
      layers[index + 1].resizeInput(layers[index - 1].weights.length);
    } else {
      // Make the new input layer accept the right sized data
      layers[index + 1].resizeInput(layers[0].weights[0].length - 1);
    }

    // Now remove the layer
    layers.removeAt(index);
  }

  void insertLayer(int index, int neuronCount) {
    // Input size is the prev layer's output or overall input.
    int inputSize = index > 0 ? layers[index - 1].weights.length : (layers[0].weights[0].length - 1);

    // Resize the one being pushed back to accept the new input size
    layers[index].resizeInput(neuronCount);

    // Add the new layer
    layers.insert(
      index,
      Layer(
        inputSize,
        neuronCount,
        activationFunction: activationFunction,
        learningRate: learningRate,
      ),
    );
  }

  /// The layer at `index` will be adjusted
  /// to have `neuronCount` sets of weights
  void changeLayerSize(int index, int neuronCount) {
    if (neuronCount == 0){
      // Remove the layer instead
      removeLayer(index);
      return;
    }
    // Change the specified layer's output count
    layers[index].resizeOutput(neuronCount);

    // Resize the next layer to accept the new input size
    layers[index + 1].resizeInput(neuronCount);
  }

  /// Returns the output of this network for input __inputs__
  List<double> forwardPropagation(List<double> inputs) {
    List<double> output;

    for (Layer layer in layers) {
      output = layer.forwardPropagation(output ?? inputs);
    }

    return output;
  }

  void backPropagation(List<double> expected) {
    // Calculate output layer
    layers.last.backPropagationOutput(expected);

    // calculate input layers
    for (int i = this.layers.length - 2; i >= 0; i--) {
      layers[i].backPropagationHidden(layers[i + 1]);
    }

    // Update all the weights
    this.layers.forEach((l) => l.updateWeights());
  }
}

// const String _e = "2.718281828459045235360287471352";

// const Map<ActivationFunction, String> _activationFunctionPythonStrings = {
//   ActivationFunction.leakyRelu: "lambda x: x if x > 0 else 0.1 * x",
//   ActivationFunction.relu: "lambda x: x if x > 0 else 0",
//   ActivationFunction.sigmoid: "lambda x: 1 / (1 + ($_e)**(-x)",
//   ActivationFunction.sigmoidish: "lambda x: 1 / (1 + ($_e)**(-x)",
//   ActivationFunction.tanh: "lambda x: (($_e)**x - ($_e)**(-x))/(($_e)**x + ($_e)**(-x))",
// };

const Map<ActivationFunction, String> activationFunctionStrings = {
  ActivationFunction.leakyRelu: "Leaky ReLU",
  ActivationFunction.relu: "ReLU",
  ActivationFunction.sigmoid: "Sigmoid",
  ActivationFunction.sigmoidish: "Sigmoidish",
  ActivationFunction.tanh: "Tanh",
};

const Map<String, ActivationFunction> stringToActivationFunction = {
  "Leaky ReLU": ActivationFunction.leakyRelu,
  "ReLU": ActivationFunction.relu,
  "Sigmoid": ActivationFunction.sigmoid,
  "Sigmoidish": ActivationFunction.sigmoidish,
  "Tanh": ActivationFunction.tanh,
};

enum ActivationFunction {
  leakyRelu,
  relu,
  sigmoid,
  sigmoidish,
  tanh,
  // softplus,
}
