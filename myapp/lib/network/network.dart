library neural_network;

import 'dart:convert';
import 'dart:math';

part 'layer.dart';
part 'neuron.dart';

class Network {
  static ActivationFunction activationFunction;
  static double learningFactor = 0.033;
  static Random r = Random();
  List<Layer> layers;
  List<int> hiddenLayerNeuronCount;
  int timesRun = 0;
  double averagePercentError = 0;
  List<double> pastErrors = List<double>();
  List<double> lastOutput = List<double>();

  String get jsonString => jsonEncode(this.toJson());
  String get prettyJsonString => JsonEncoder.withIndent('  ').convert(this.toJson());
  String get matrixString => matrix.toString();

  List<List<List<double>>> get matrix {
    List<List<List<double>>> values = List<List<List<double>>>(this.layers.length);
    for (int layerIndex = 0; layerIndex < this.layers.length; layerIndex++) {
      values[layerIndex] = List<List<double>>();
      for (int neuronIndex = 0; neuronIndex < layers[layerIndex].neurons.length; neuronIndex++) {
        values[layerIndex].add(layers[layerIndex].neurons[neuronIndex].weights);
      }
    }
    return values;
  }

  int get maxLayerSize {
    int max = 0;
    for (Layer l in layers) {
      if (l.neurons.length > max) {
        max = l.neurons.length;
      }
    }

    return max;
  }

  Network(
    this.hiddenLayerNeuronCount, {
    ActivationFunction activationFunction,
    this.layers,
  }) {
    Network.activationFunction = activationFunction ?? ActivationFunction.sigmoid;
    this.layers ??= List<Layer>();
    // Add a layer for each count
    for (int i = 0; i < hiddenLayerNeuronCount.length - 1; i++) {
      layers.add(
        Layer(
          hiddenLayerNeuronCount[i],
          hiddenLayerNeuronCount[i + 1],
        ),
      );
    }
  }

  factory Network.fromJsonString(String jsonString) {
    Map<String, dynamic> map = jsonDecode(jsonString);
    return Network.fromJson(map);
  }

  factory Network.fromJson(Map<String, dynamic> map) {
    Network.learningFactor = map["learningFactor"];
    Network n = Network([0]);
    n.layers = map["layers"].map<Layer>((lString) => Layer.fromJson(lString)).toList();
    n.timesRun = map["timesRun"];
    n.hiddenLayerNeuronCount = map["hiddenLayerNeuronCount"];
    n.averagePercentError = map["averagePercentError"];
    n.pastErrors = map["pastErrors"];
    n.lastOutput = map["lastOutput"];

    return n;
  }

  Map<String, dynamic> toJson() {
    var output = {
      "timesRun": this.timesRun,
      "learningFactor": Network.learningFactor,
      "hiddenLayerNeuronCount": this.hiddenLayerNeuronCount,
      "averagePercentError": this.averagePercentError,
      "pastErrors": this.pastErrors,
      "lastOutput": this.lastOutput,
      "layers": this.layers.map<Map<String, dynamic>>((l) => l.toJson()).toList(),
    };
    return output;
  }

  void reset() {
    timesRun = 0;
    pastErrors.clear();
    averagePercentError = 0;

    for (Layer layer in layers) {
      for (Neuron neuron in layer.neurons) {
        neuron.reset();
      }
    }
  }

  /// Returns the output of this network for input __inputs__
  List<double> forwardPropagation(List<double> inputs) {
    List<double> output;

    for (Layer layer in layers) {
      output = layer.forwardPropagation(output ?? inputs);
    }

    lastOutput = output;

    return output;
  }

  void backPropagation(List<double> expected) {
    timesRun++;
    _calculateError(expected);

    // Calculate output layer
    layers[layers.length - 1].backPropagationOutput(expected);

    // calculate input layers
    for (int i = this.layers.length - 2; i >= 0; i--) {
      layers[i].backPropagationHidden(layers[i + 1]);
    }

    // Update all the weights
    this.layers.forEach((l) => l.updateWeights());
  }

  /// Calculate the error of the last output
  void _calculateError(List<double> expected) {
    double expectedSum = 0;
    for (double v in expected) expectedSum += v;
    double calculatedSum = 0;
    for (double v in layers.last.outputs) calculatedSum += v;
    if (expectedSum != 0) {
      double currentError = expectedSum > 0 ? (expectedSum - calculatedSum) / expectedSum * 100 : 0;
      pastErrors.add(currentError);
      // reset average
      averagePercentError = 0;
      // sum up errors
      pastErrors.forEach((e) => averagePercentError += e);
      // divide by length
      averagePercentError /= pastErrors.length;
      if (pastErrors.length > 5 && currentError > 0) {
        pastErrors.removeAt(0);
      }
    }
  }
}
