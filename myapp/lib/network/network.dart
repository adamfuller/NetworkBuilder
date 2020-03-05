library neural_network;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

part 'layer.dart';
part 'neuron.dart';

const double _defaultLearningRate = 0.033;
const ActivationFunction _defaultActivationFunction = ActivationFunction.sigmoid;

class Network {
  //
  // Private static
  //
  static Isolate _trainingIsolate;
  static ReceivePort _trainingPort;
  static Capability _resumeCapability = Capability();
  static SendPort isolateNetworkUpdater;
  //
  // Public static
  //
  static double mutationFactor = 0.0033;
  static Random r = Random();
  static bool isolateIsPaused = false;

  //
  // Private fields
  //
  List<double> _lastOutput = List<double>();

  //
  // Public fields
  //
  List<Layer> layers;
  List<int> hiddenLayerNeuronCount;

  /// How many times has this been run under the same state
  int runCount = 0;

  /// Average Percent Error of the last few runs
  double averagePercentError = 0;
  List<double> pastErrors = List<double>();

  /// Outputs from running test data through single forwardProp
  List<List<double>> testOutputs = List<List<double>>();
  List<List<double>> trainingInputs;
  List<List<double>> trainingOutputs;

  /// SendPort used if in another Isolate
  SendPort trainingSendPort;

  String get jsonString => jsonEncode(this.toJson());
  String get prettyJsonString => JsonEncoder.withIndent('  ').convert(this.toJson());
  String get matrixString => matrix.toString();
  static get isUsingIsolate => _trainingIsolate != null;

  /// Returns the learning rate of the first neuron
  ///
  /// Will be removed once learningRate is unique.
  double get learningRate => this.layers[0].neurons[0].learningRate;

  /// Sets the learning rate of each neuron to the same value
  set learningRate(double val) => this.layers.forEach((layer) => layer.neurons.forEach((n) => n.learningRate = val));

  /// Sets the Activation Function of each neuron to the same one
  set activationFunction(ActivationFunction av) => this.layers.forEach((layer) => layer.neurons.forEach((n) => n.activationFunction = av));

  /// Returns the Activation Function of the first neuron
  ///
  /// Will be removed once activationFunction is unique.
  ActivationFunction get activationFunction => this.layers[0].neurons[0].activationFunction;

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
    ActivationFunction activationFunction = _defaultActivationFunction,
    this.layers,
    double learningRate = _defaultLearningRate,
    this.averagePercentError = 0,
    this.runCount = 0,
    this.testOutputs,
  }) {
    if (this.layers == null) {
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
    // Set values for the learning rate of each neuron
    this.learningRate = learningRate ?? _defaultLearningRate;
    // Set each neurons activation function
    this.activationFunction = activationFunction ?? _defaultActivationFunction;
    this.testOutputs = [];
  }

  static void stopIsolate() {
    // if (Network._trainingIsolate == null) return;
    Network._trainingIsolate?.kill(priority: Isolate.immediate);
    Network._trainingPort?.close();
    Network._trainingIsolate = null;
  }

  static void pauseIsolate() {
    Network.isolateIsPaused = true;
    Network._resumeCapability = Network._trainingIsolate?.pause();
  }

  static void resumeIsolate() {
    Network.isolateIsPaused = false;
    Network._trainingIsolate?.resume(Network._resumeCapability);
    _resumeCapability = null;
  }

  static Future<void> _sleep(int milliseconds) async => await Future.delayed(Duration(milliseconds: milliseconds), () => "");

  ///Train a network in an Isolate
  ///
  ///Passes modified network to callback upon each round of training
  static void trainInIsolate(
    Network network,
    List<List<double>> inputs,
    List<List<double>> expectedOutputs, {
    void Function(Network) callback,
    void Function() onDone,
  }) async {
    // Isolate has already been set! Don't do it again
    if (Network._trainingIsolate != null) return;

    // Isolate needs a function that will accept:
    //  a network
    Network copy = network.copy();
    Network._trainingPort = ReceivePort();
    copy.trainingSendPort = Network._trainingPort.sendPort;

    // Copy over the inputs and expected outputs
    copy.trainingInputs = inputs;
    copy.trainingOutputs = expectedOutputs;

    Network._trainingIsolate = await Isolate.spawn(trainingFunction, copy);

    _trainingPort.listen((n) {
      if (n.runtimeType == Network) {
        // network = n;
        if (callback != null) callback(n);
      } else {
        isolateNetworkUpdater = n;
      }
    }, onDone: () {
      // Send a final copy of the network
      if (onDone != null) onDone();
    });
  }

  /// Train a network
  ///
  /// This is for use when spawning isolates
  ///
  /// Set cycleDelay to null for no delay between trainings.
  static Future<Network> trainingFunction(
    Network network, {
    int maxRuns,
    int updatePeriodMilliseconds = 100,
    int cycleDelay = 16,
  }) async {
    if (!(network?.trainingInputs?.isNotEmpty ?? false) || !(network?.trainingOutputs?.isNotEmpty ?? false)) {
      print("\n\nTHEY HAVE NO TRAINING INPUTS!!\n\n");
      return null;
    }
    SendPort sp = network.trainingSendPort;
    ReceivePort rp = ReceivePort();
    Network temp;

    sp.send(rp.sendPort);

    // Setup the adjuster
    rp.listen((message) {
      if (message.runtimeType == Network) {
        ///
        //////// CONSIDER USING TEMP TO UPDATE ON NEXT CYCLE
        ///
        temp = message;
      }
    });

    DateTime lastSent = DateTime.now();
    int i = 0;

    // Incase someone set it to null...
    updatePeriodMilliseconds ??= 100;
    int networkRuns = network.runCount;

    while (maxRuns == null || i < maxRuns) {
      i++;
      // If training in another isolate only tick up for whole data set
      network.runCount++;
      network.averagePercentError = 0;
      network.pastErrors.clear();
      network.testOutputs.clear();
      // Iterate through data and train
      for (int i = 0; i < network.trainingInputs.length; i++) {
        // Record the outputs
        network.testOutputs.add(network.forwardPropagation(network.trainingInputs[i]));
        network.backPropagation(network.trainingOutputs[i]);
      }

      if (temp != null) {
        network = temp;
        temp = null;
      }

      // Send out an update every 100 ms or whatever is send
      if (DateTime.now().difference(lastSent).inMilliseconds > updatePeriodMilliseconds) {
        sp?.send(network);
        lastSent = DateTime.now();
      }

      // Delay 10ms to reduce CPU load
      if (cycleDelay != null && cycleDelay > 0) await _sleep(cycleDelay);
    }
    // Override present value
    network.runCount = networkRuns + i;
    return network;
  }

  ///Perform back propagation with a map of format:
  /// ```
  /// Network n = Network([1,1]);
  /// List<double> data = [0.0,];
  /// Map<String,dynamic> map = {
  ///   'network': n,
  ///   'data': data,
  /// }
  /// ```
  /// Returns a Network after performing back propagation
  /// 
  /// Returns null if `"network"` or `"data"` are not present in `map`
  static Network _backPropagationFromMap(Map<String, dynamic> map) {
    // Check that the network is present
    if (!map.containsKey("network")) return null;
    // Check that the data is present
    if (!map.containsKey("data")) return null;
    // Get the network from the map
    Network network = map["network"];
    // Get the data from the map
    List<double> data = map["data"];
    // Perform standard back propagation
    network.backPropagation(data);
    return network;
  }

  /// Returns a version of this network that has been back propagated for `expectedOutput`
  Future<Network> asyncBackProp(List<double> expectedOutput) async {
    return compute(Network._backPropagationFromMap, {
      "network": this,
      "data": expectedOutput,
    });
  }

  factory Network.fromJsonString(String jsonString) {
    Map<String, dynamic> map = jsonDecode(jsonString);
    return Network.fromJson(map);
  }

  factory Network.fromJson(Map<String, dynamic> map) {
    Network n = Network(
      [0],
      layers: map["layers"].map<Layer>((lString) => Layer.fromJson(lString)).toList(),
      averagePercentError: map["averagePercentError"],
      runCount: map["runCount"],
      testOutputs: map["testOutputs"],
      learningRate: map["learningRate"],
      activationFunction: ActivationFunction.values[map["activationFunction"]],
    );
    n.hiddenLayerNeuronCount = map["hiddenLayerNeuronCount"];
    n.pastErrors = map["pastErrors"];
    n._lastOutput = map["lastOutput"];

    return n;
  }

  Network copy() => Network.fromJson(this.toJson());

  Map<String, dynamic> toJson() {
    var output = {
      "mutationFactor": Network.mutationFactor,
      "runCount": this.runCount,
      "learningRate": this.learningRate,
      "hiddenLayerNeuronCount": this.hiddenLayerNeuronCount,
      "averagePercentError": this.averagePercentError,
      "pastErrors": this.pastErrors,
      "lastOutput": this._lastOutput,
      "layers": this.layers?.map<Map<String, dynamic>>((l) => l.toJson())?.toList(),
      "testOutputs": this.testOutputs,
      "activationFunction": ActivationFunction.values.indexOf(this.activationFunction),
    };
    return output;
  }

  void setTrainingInput(List<List<double>> inputs) => trainingInputs = inputs;
  void setTrainingOutput(List<List<double>> outputs) => trainingOutputs = outputs;

  void reset() {
    runCount = 0;
    pastErrors.clear();
    averagePercentError = 0;

    for (Layer layer in layers) {
      for (Neuron neuron in layer.neurons) {
        neuron.reset();
      }
    }
  }

  Network produceMutation() {
    Network copy = Network.fromJson(this.toJson());
    copy.mutate();
    return copy;
  }

  void mutate() {
    this.layers.forEach((l) => l.mutate());
  }

  /// Returns the output of this network for input __inputs__
  List<double> forwardPropagation(List<double> inputs) {
    List<double> output;

    for (Layer layer in layers) {
      output = layer.forwardPropagation(output ?? inputs);
    }

    _lastOutput = output;

    return output;
  }

  void backPropagation(List<double> expected) {
    if (this.trainingSendPort == null) runCount++;
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
