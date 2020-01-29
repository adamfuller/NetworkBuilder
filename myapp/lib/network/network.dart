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
  List<double> lastOutput;

  // double get learningFactor => _learningFactor/(timesRun+1) + _learningFactor/10;

  String get jsonString => jsonEncode(this.toJson());
  String get prettyJsonString => JsonEncoder.withIndent('  ').convert(this.toJson());

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
    Network.activationFunction ??= ActivationFunction.sigmoid;
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
    return {
      "layers": this.layers.map<Map<String, dynamic>>((l) => l.toJson()).toList(),
      "timesRun": this.timesRun,
      "learningFactor": Network.learningFactor,
      "hiddenLayerNeuronCount": this.hiddenLayerNeuronCount,
      "averagePercentError": this.averagePercentError,
      "pastErrors": this.pastErrors,
      "lastOutput": this.lastOutput,
    };
  }

  /// Returns the output of this network for input __inputs__
  List<double> feedForward(List<double> inputs) {
    List<double> output;

    this.layers.forEach((layer) {
      output = layer.forwardPropagation(output ?? inputs);
    });
    lastOutput = output;

    return output;
  }

  void backPropagation(List<double> expected) {
    timesRun++;
    double expectedSum = 0;
    for (double v in expected) expectedSum += v;
    double calculatedSum = 0;
    for (double v in this.layers.last.outputs) calculatedSum += v;
    double currentError = expectedSum > 0 ? (expectedSum - calculatedSum) / expectedSum * 100 : 0;
    pastErrors.add(currentError);
    this.averagePercentError = 0;
    for (int i = 0; i < pastErrors.length; i++) {
      averagePercentError += pastErrors[i];
    }
    averagePercentError /= pastErrors.length;
    if (pastErrors.length > 5 && currentError > 0) {
      pastErrors.removeAt(0);
    }
    //
    // End of error calculation
    //

    // Calculate output layer
    layers[layers.length - 1].backPropagationOutput(expected);

    // calculate input layers
    for (int i = this.layers.length - 2; i >= 0; i--) {
      layers[i].backPropagationHidden(layers[i + 1].gamma, layers[i + 1].weightsByNeuron);
    }

    // Update all the weights
    this.layers.forEach((l) => l.updateWeights());
  }
}
