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

  //
  // Getters
  //

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
    this.trainingTimer?.cancel();
    isTraining = false;
    this.network = Network(
      [3, 15, 5, 15, 1],
      normalizationFunction: ActivationFunction.softplus,
    );

    this.isLoading = false;
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
  }

  void outputPressed() {
    print(this.network.feedForward([0, 1, 0]));
  }

  void toggleTraining() {
    isTraining = !isTraining;
    onDataChanged();
    if (isTraining) {
      trainingTimer = Timer.periodic(Duration(milliseconds: 100), (t) {
        List<List<double>> inputs = [
          [0, 0, 0],
          [0, 0, 1],
          [0, 1, 0],
          [0, 1, 1],
          [1, 0, 0],
          [1, 0, 1],
          [1, 1, 0],
          [1, 1, 1],
        ];
        List<List<double>> outputs = [
          [0],
          [1],
          [1],
          [0],
          [1],
          [0],
          [0],
          [0],
        ];
        for (int j = 0; j < outputs.length; j++) {
          this.network.feedForward(inputs[j]);
          this.network.backPropagation(outputs[j]);
        }
        // for (int j = 0; j < inputs.length; j++) {
        //   print("${inputs[j]}, ${this.network.feedForward(inputs[j])}");
        // }
        onDataChanged();
      });
    } else {
      trainingTimer.cancel();
    }
  }

  void trainPressed() {
    List<List<double>> inputs = [
      [0, 0, 0],
      [0, 0, 1],
      [0, 1, 0],
      [0, 1, 1],
      [1, 0, 0],
      [1, 0, 1],
      [1, 1, 0],
      [1, 1, 1],
    ];
    List<List<double>> outputs = [
      [0],
      [1],
      [1],
      [0],
      [1],
      [0],
      [0],
      [0],
    ];
    for (int i = 0; i < 1; i++) {
      for (int j = 0; j < outputs.length; j++) {
        this.network.feedForward(inputs[j]);
        this.network.backPropagation(outputs[j]);
      }
    }
    // for (int j = 0; j < inputs.length; j++) {
    //   print("${inputs[j]}, ${this.network.feedForward(inputs[j])}");
    // }
  }
}
