\m5_TLV_version 1d: tl-x.org
\m5
   
   // ======================
   // Simple Examples of VIZ
   // ======================
   
\SV
   m5_makerchip_module
\TLV
   // This file illustrates concepts of Makerchip's Visual Debug feature.
   // A series of examples are presented, each defined in its own unit of
   // hardware, named "exampleX".
   
   // Define a hardware unit for Example 1 (containing no hardware).
   /example1
      // Define a visual representation of this (empty) hardware unit.
      \viz_js
         // Initialize this visual component with some basic shapes.
         // The init() function is called once per compilation and returns FabricJS objects
         // that initialize the component.
         // VIZ docs can be found under the "LEARN" menu.
         // FabricJS examples can be found at http://fabricjs.com/demos.
         init() {
            return {
               text: new fabric.Text("Example 1",
                                     {left: 0, top: -12,
                                      fontSize: 10,
                                      fill: "darkgreen"}),
               square: new fabric.Rect({left: 0, top: 0, width: 20, height: 20,
                                        stroke: "darkblue", fill: "blue"}),
               circle: new fabric.Circle({left: 10, top: 20, radius: 10,
                                          stroke: "brown", fill: "pink"}),
               line: new fabric.Line([-5, 0, 5, 40],
                                     {stroke: "red"}),
               frog: this.newImageFromURL(
                          "https://raw.githubusercontent.com/stevehoover/makerchip_examples/master/viz_imgs/frog.png",
                          "",
                          {left: 14, top: 5,
                           scaleX: 0.03, scaleY: 0.03
                          })
            }
         },
         // Place this component in it's parent's coordinate system.
         where: {left: 0, top: 0, width: 10, height: 10}
   
   /example2
      // Since example1 is only creating shapes (excluding the image), we could use this condensed syntax
      // instead.
      // The template field defines FabricJS objects.
      \viz_js
         template: {
            text: ["Text", "Example 2",
                           {left: 0, top: -12,
                            fontSize: 10,
                            fill: "darkgreen"}],
            square: ["Rect", {left: 0, top: 0, width: 20, height: 20,
                              stroke: "darkblue", fill: "blue"}],
            circle: ["Circle", {left: 10, top: 20, radius: 10,
                                stroke: "brown", fill: "pink"}],
            line: ["Line", [-5, 0, 5, 40],
                          {stroke: "red"}]
         },
         where: {left: 20, top: 0, width: 10, height: 10}
   
   /example3[2:0]
      // This hardware unit is replicated three times (by the range [2:0]).
      // It's visual representation will be replicated as well.
      \viz_js
         template: {
            circle: ["Circle", {left: 0, top: 0, radius: 5}]
         },
         where: {left: 40, top: 0, width: 10, height: 10}
   
   /example4
      // The hardware is defined in a hierarchy of components, like:
      /unit1
         /block1
         /block2
      /unit2[1:0]  // Two instances
         /block1
         /block2[5:0]   // Six instances
      // ...
      // (These are all empty.)
      
      // Each hardware component in the hardware design's hierarchy
      // can have a visual representation or not.
      /unit1   // (This is the same /unit1 as above.)
         \viz_js
            template: {hi: ["Text", "Example"]},
            where: {left: 0, top: 0}
         /block1
            \viz_js
               template: {there: ["Text", "4", {fill: "green"}]},
               where: {left: 160, top: 0}
         /block2
      /unit2[1:0]  // Two instances
         /block1
         /block2[5:0]   // Six instances
            \viz_js
               template: {yo: ["Text", "Yo"]},
               where: {left: 0, top: 60}
      \viz_js
         where: {left: 60, top: 0, width: 10, height: 10}
         
   /example5
      // Each component has a bounding box. By default, this box will be sized to contain all
      // template/init objects. Here, we'll be explicit, and we'll define the box's properties
      // using the properties of a rectangle.
      \viz_js
         box: {left: 0, top: -10, width: 30, height: 20,
               strokeWidth: 2, stroke: "red", fill: "gray"},
         template: {circle: ["Circle", {left: 0, top: 0, radius: 5,
                                        fill: "blue", strokeWidth: 0}]},
         where: {left: 80, top: 0, width: 10, height: 10}
   
   /example6
      // For replicated components, you can:
      //   1) define a component for the collection of instances (using all: ...)
      //   2) control the layout of instances
      //   3) initialize each instance differently (using this.getIndex())
      /ring[9:0]
         \viz_js
            // 1)
            all: {
               box: {width: 10, height: 10},
               template: {title: ["Text", "Example 6", {fontSize: 1}]}
            },
            box: {width: 50, height: 100},
            // 2)
            layout: {top: 0, left: 0, angle: 36},
            init() {return {
               ind: new fabric.Text(
                  // 3)
                  this.getIndex().toString(),
                  {top: 40})}},
            where0: {left: 5, top: 5, width: 5, height: 5},
            where: {left: 100, top: 0, width: 10, height: 10}
   
   /example7
      // Okay, but how do we connect these with simulation?
      //   1) render() is called each time the cycle changes.
      //   2) It has access to values from the simulation.
      //   3) And it can use them to change properties of FabricJS objects.
      // Let's start with Verilog.
      \SV_plus
         logic [7:0] temp;  // (as in "temperature")
         always_ff @(posedge clk) begin
            temp <= reset ? 0 : temp + $rand_v[3:0];  // (Using TLV for random.)
         end
      \viz_js
         box: {left: -1, top: -41, width: 22, height: 298, strokeWidth: 1, stroke: "blue"},
         template: {
            title: ["Text", "Example 7", {top: -40}],
            mercury: ["Rect", {left: 0, top: 256, width: 20, height: 0,
                               fill: "maroon", strokeWidth: 0}]},
         // 1)
         render() {
            // 2)
            let temp = this.sigVal("temp").asInt()
            // 3) 
            this.getObjects().mercury.set({height: temp, top: 256 - temp})
         },
         where: {left: 0, top: 20, width: 10, height: 10}
      // Drag the slider and watch the thermometer heat up.
      // Note that signals are referenced using fully-qualified signal names relative to the
      // "top" module, e.g. "my_module_instance.my_loop.my_sig". TL-Verilog hierarchy is irrelevant
      // except to define the visual hierarchy.
      
   /example8
      // Now using TL-Verilog.
      // Pipesignal values are accessed using TL-Verilog pipesignal reference syntax 
      // within single quotes (below, "'$temp'").
      // Note that JavaScript strings must use double quotes, so be careful when copying
      // in arbitrary JavaScript code.
      $temp[7:0] = *reset ? 0 : >>1$temp + $rand[3:0];
      \viz_js
         box: {left: -1, top: -41, width: 22, height: 298, strokeWidth: 1},
         template: {
            title: ["Text", "Example 8", {top: -40}],
            mercury: ["Rect", {left: 0, top: 256, width: 20, height: 0, fill: "red", strokeWidth: 0}]},
         render() {
            let temp = '$temp'.asInt()
            this.getObjects().mercury.set({height: temp, top: 256 - temp})
         },
         where: {left: 20, top: 20, width: 10, height: 10}
      // Note that \viz_js blocks are like TL-Verilog logic expressions with no outputs.
      //   o Pipesignal references are relative to the scope of the \viz_js block and can
      //     reference through hierarchy, pipelines, and using alignment values, e.g.:
      //     '/foo[2]|pipe>>2$temp'.
      //   o But, indices within references are JavaScript expressions, e.g. "[2]"
      //     or "[this.getIndex()]".
      //   o SandPiper reports warnings for bad references.
      //   o You can see highlighting on the signal reference in NAV-TLV.

   /example9
      // Signal values can be accessed from anywhere in the entire simulation, not just at
      // the current time.
      //   o A signal value lookup (e.g. '$temp' or this.sigVal("temp")) returns a new object
      //     (SignalValue) that can access the value of a signal at the current time (with
      //     respect to TL-Verilog scope and the given alignment).
      //   o Values are accessed from a SignalValue object using, e.g. '$temp'.asInt().
      //   o We can adjust the cycle time of a SignalValue using, e.g. '$temp'.step(-2) to
      //     reference two cycles earlier.
      // This example plots temperature over the past 16 cycles instead of showing a
      // thermometer that represents only a moment in time. It uses $temp from /example8.
      \viz_js
         box: {left: -257, top: -41, width: 258, height: 298, strokeWidth: 1},
         init() {
            let ret = {title: new fabric.Text("Example 9", {left: -257, top: -40})}
            for (let i = 0; i > -16; i--) {
               ret[i] = new fabric.Rect({left: (i-1) * 16, top: 256, width: 16, height: 0, fill: "red", strokeWidth: 0})
            }
            return ret
         },
         render() {
            let $temp = '/top/example8$temp'
            for (let i = 0; i > -16; i--) {
               temp = $temp.asInt(0)  // Default to 0 is outside trace.
               this.getObjects()[i].set({height: temp, top: 256 - temp})
               $temp.step(-1)
            }
         },
         where: {left: 40, top: 20, width: 10, height: 10}
         
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
