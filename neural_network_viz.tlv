\m4_TLV_version 1d: tl-x.org
\SV

m4+definitions(['   
   m4_define(['M4_PRETRAINED'],1)
   m4_define(['M4_INPUTDATAWIDTH'],8)
   m4_define(['M4_NUMWEIGHT_LAYER1'],30)
   m4_define(['M4_NUMWEIGHT_LAYER2'],30)
   m4_define(['M4_NUMWEIGHT_LAYER3'],30)
   m4_define(['M4_WEIGHTINTWIDTH'],1)
   m4_define(['M4_ADDRESSWIDTH'],5)
   m4_define(['M4_NUM_LAYER1_NEURONS'],30)
   m4_define(['M4_NUM_LAYER2_NEURONS'],30)
   m4_define(['M4_NUM_LAYER3_NEURONS'],30)
'])
//Bias Memory - it contains only a single BIAS value (hence only need for 'rd_en' and 'rd_address' ports)
//parameter : /_top             -> top scope for bias memory
//            /_biasmem_scope   -> scope of bias memory
//            #_inputdatawidth  -> inputDataWidth
//            @_stage_wr        -> Write stage (prensently not used)
//            @_stage_rd        -> Read stage (FETCH stage)
//            $_biasmem_rd_data -> Output from bias memory
\TLV biasmem(/_top, /_biasmem_scope, #_inputdatawidth, @_stage_wr, @_stage_rd, $_biasmem_rd_data)
   m4_default(['M4_PRETRAINED'], 1)
   m4_ifelse_block(M4_PRETRAINED, 1, ['
   /_top
      @_stage_wr
         \SV_plus
            logic [#_inputdatawidth-1:0] biasmem [0:0];
            assign biasmem = '{
               {#_inputdatawidth'b1000}
             };
         /_biasmem_scope
            $value[#_inputdatawidth-1:0] = *biasmem\[0\]; 
   '], ['
   /_top
      @_stage_wr
         /_biasmem_scope
            $wr = $biasmem_wr_en;
            $value[#_inputdatawidth-1:0] = $reset ? '0 : $biasmem_wr_data;
   '])
   /_top
      @_stage_rd
         $_biasmem_rd_data[#_inputdatawidth-1:0] = /_biasmem_scope>>m4_stage_eval(1)$value;
   

//Weight Memory - it contains Weights value stored in array (presently doesnt support write operation)
//parameter : /_top             -> top scope for weight memory
//            /_mem_scope       -> scope of weight memory
//            #_inputdatawidth  -> inputDataWidth
//            #_numdepth        -> Number of weights per neuron
//            @_stage_wr        -> Write stage (prensently not used)
//            @_stage_rd        -> Read stage (FETCH stage)
//            $_mem_rd_en       -> weigth memory read enable
//            $_mem_rd_address  -> weight memory rrread address
//            $_mem_rd_data     -> Output data from weight memory
\TLV weightmem(/_top, /_mem_scope, #_inputdatawidth, #_numdepth, @_stage_wr, @_stage_rd, $_mem_rd_en, $_mem_rd_address, $_mem_rd_data)
   m4_pushdef(['m4_mem_scope'], m4_strip_prefix(/_mem_scope))
   m4_default(['M4_PRETRAINED'], 1)
   m4_ifelse_block(M4_PRETRAINED, 1, ['
   /_top
      @_stage_wr
         \SV_plus
            logic [#_inputdatawidth-1:0] mem [#_numdepth-1:0];
            //\$readmemb(weightfile, mem);
            assign mem = '{
               {#_inputdatawidth'b000},
               {#_inputdatawidth'b10},
               {#_inputdatawidth'b1},
               {#_inputdatawidth'b01},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b00},
               {#_inputdatawidth'b000},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b101},
               {#_inputdatawidth'b11},
               {#_inputdatawidth'b00},
               {#_inputdatawidth'b11},
               {#_inputdatawidth'b1},
               {#_inputdatawidth'b10},
               {#_inputdatawidth'b00},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b1},
               {#_inputdatawidth'b011},
               {#_inputdatawidth'b10},
               {#_inputdatawidth'b00},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b001},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0},
               {#_inputdatawidth'b0011}
             };
         /_mem_scope[#_numdepth-1:0]
            $value[#_inputdatawidth-1:0] = *mem\[#m4_mem_scope\]; 
   '], ['
   /_top
      @_stage_wr
         /_mem_scope[#_numdepth-1:0]
            $wr = $mem_wr_en && ($mem_wr_address == #m4_mem_scope);
            $value[#_inputdatawidth-1:0] = $reset ?   '0           :
                           $wr        ?   $mem_wr_data :
                                          $RETAIN;
   '])
   /_top
      @_stage_rd
         $_mem_rd_data[#_inputdatawidth-1:0] = ($_mem_rd_en) ? /_mem_scope[$_mem_rd_address]>>m4_stage_eval(1)$value : '0;
   
   m4_popdef(['m4_mem_scope'])
   
//Neuron - Architecture of single neuron
//parameter : /_top             -> top scope for neuron
//            /_biasmem         -> scope for bias memory
//            /_weightmem       -> scope of weight memory
//            #_layernum        -> Indicates this neuron is part of which layer (i.e. column) 
//            #_neuronnum       -> Indicates the number of this neuron (i.e. row)
//            #_pipedepth       -> No. of Pipeline depth in neuron (presently supports only 5 cofiguration with max 4-cycle of depth)
//            #_numinputweights -> No. of input weights(i.e. previous layer's neuronnum) to this neuron.          
//            #_inputdatawidth  -> inputDataWidth
//            #_weightintwidth  -> weight int value(because of fixed point format) 
//            $_reset           -> external reset
//            $_myinput         -> input data to neuron(1-by-1)
//            $_myinputvalid    -> input data valid
//            $_out             -> output from neuron (after all the (#_numinputweights + #_pipedepth) cycles from 1st valid input)
//            $_outvalid        -> 1-cycle output valid
//Working :-  The valid "input value' gets multipled with "valid weight value" and is accumulated and at last cycle
//            the finalsum is added with bias, which then passes though "ReLU" activation function
//            (due to fixed #_inputdatawidth, we saturate the max relu value to 1 when it overflows).
\TLV neuron(/_top, /_neuron, /_biasmem, /_weightmem, #_layernum, #_neuronnum, #_pipedepth, #_numinputweights, #_inputdatawidth, #_weightintwidth, $_reset, $_myinput, $_myinputvalid, $_out, $_outvalid)
   m4_pushdef(['m4_pipenum'], #_pipedepth) // configuring stages based on #_pipedepth 
   m4_default(['m4_pipenum'], 1)
   m4_case(m4_pipenum, 1, ['
   m4_pushdef(['M4_FETCH_STAGE'],0)
   m4_pushdef(['M4_MUL_STAGE'],0)
   m4_pushdef(['M4_SUM_STAGE'],0)
   m4_pushdef(['M4_ACT_STAGE'],0)
   m4_pushdef(['M4_OUT_STAGE'],0)
   '], 2, ['
   m4_pushdef(['M4_FETCH_STAGE'],0)
   m4_pushdef(['M4_MUL_STAGE'],0)
   m4_pushdef(['M4_SUM_STAGE'],0)
   m4_pushdef(['M4_ACT_STAGE'],1)
   m4_pushdef(['M4_OUT_STAGE'],1)
   '], 3, ['
   m4_pushdef(['M4_FETCH_STAGE'],0)
   m4_pushdef(['M4_MUL_STAGE'],1)
   m4_pushdef(['M4_SUM_STAGE'],1)
   m4_pushdef(['M4_ACT_STAGE'],2)
   m4_pushdef(['M4_OUT_STAGE'],2)
   '], 4, ['
   m4_pushdef(['M4_FETCH_STAGE'],0)
   m4_pushdef(['M4_MUL_STAGE'],1)
   m4_pushdef(['M4_SUM_STAGE'],2)
   m4_pushdef(['M4_ACT_STAGE'],3)
   m4_pushdef(['M4_OUT_STAGE'],3)
   '], 5, ['
   m4_pushdef(['M4_FETCH_STAGE'],0)
   m4_pushdef(['M4_MUL_STAGE'],1)
   m4_pushdef(['M4_SUM_STAGE'],2)
   m4_pushdef(['M4_ACT_STAGE'],3)
   m4_pushdef(['M4_OUT_STAGE'],4)
   ']
   )
   m4_define(['M4_ADDRESSWIDTH'], \$clog2(#_numinputweights))

   
   /_neuron
      @M4_FETCH_STAGE
         $irst = /_top<>0$_reset;
         $input[#_inputdatawidth-1:0] = $rand[#_inputdatawidth-1:0]; // /_top$_myinput[#_inputdatawidth-1:0];
         $input_valid = /_top$_myinputvalid;
   m4+biasmem(/_neuron,/_biasmem, #_inputdatawidth, @M4_FETCH_STAGE, @M4_FETCH_STAGE, $biasReg)
   /_neuron
      @M4_FETCH_STAGE
         $bias[(2 * #_inputdatawidth) - 1 : 0] = {$biasReg[#_inputdatawidth-1:0] ,{#_inputdatawidth{1'b0}}};

         $mem_rd_address[M4_ADDRESSWIDTH:0] = ($irst | >>m4_eval(M4_OUT_STAGE - M4_FETCH_STAGE + 1)$_outvalid ) ? '0                       :
                               ($input_valid) ? >>1$mem_rd_address + 1'b1 :
                                                   $RETAIN;

         $mem_rd_en = $input_valid;
   m4+weightmem(/_neuron, /_weightmem, #_inputdatawidth, #_numinputweights, @M4_FETCH_STAGE, @M4_MUL_STAGE, $mem_rd_en, $mem_rd_address, $mem_out)
   /_neuron
      @M4_MUL_STAGE
         $mul[(2 * #_inputdatawidth)-1:0] = \$signed($input) * \$signed($mem_out); // $signed multiplication
   /_neuron
      @M4_SUM_STAGE
         $sumAdd[(2 * #_inputdatawidth)-1:0] = $mul + >>1$sum;
         $biasAdd[(2 * #_inputdatawidth)-1:0] = $bias + >>1$sum;

         $sum[(2 * #_inputdatawidth)-1:0] = ($irst | >>m4_eval(M4_OUT_STAGE - M4_SUM_STAGE + 1)$_outvalid)     ? '0 :
                 (($mem_rd_address == #_numinputweights) && (!$input_valid & >>1$input_valid)) ? (
                 ((! $bias[(2 * #_inputdatawidth)-1]) & (! >>1$sum[(2 * #_inputdatawidth)-1]) & (  $biasAdd[(2 * #_inputdatawidth)-1])) ? {1'b0, {((2 * #_inputdatawidth)-1){1'b1}}} :  // Overflow between bias and sum
                 ((  $bias[(2 * #_inputdatawidth)-1]) & (  >>1$sum[(2 * #_inputdatawidth)-1]) & (! $biasAdd[(2 * #_inputdatawidth)-1])) ? {1'b1, {((2 * #_inputdatawidth)-1){1'b0}}} :  // Underflow between bias and sum
                                                  {$biasAdd} ) :
                         ($input_valid) ? (
                 ((! $mul[(2 * #_inputdatawidth)-1]) & (! >>1$sum[(2 * #_inputdatawidth)-1]) & (  $sumAdd[(2 * #_inputdatawidth)-1])) ? {1'b0, {((2 * #_inputdatawidth)-1){1'b1}}} :    // Overflow between weight and sum
                 ((  $mul[(2 * #_inputdatawidth)-1]) & (  >>1$sum[(2 * #_inputdatawidth)-1]) & (! $sumAdd[(2 * #_inputdatawidth)-1])) ? {1'b1, {((2 * #_inputdatawidth)-1){1'b0}}} :    // Underflow between weight and sum
                                                  {$sumAdd} ) : '0;

      @M4_ACT_STAGE
         $actvalid = (($mem_rd_address == #_numinputweights) && (!$input_valid & >>1$input_valid));
         // "ReLU" activation function
         ?$actvalid
            $out_act[#_inputdatawidth-1:0] = ($sum[(2 * #_inputdatawidth)-1] == 0) ? (
                                          (| $sum[(2 * #_inputdatawidth)-1 -: #_weightintwidth+1]) ? {1'b0, {(#_inputdatawidth-1){1'b1}}} : {$sum[(2 * #_inputdatawidth)-1-#_weightintwidth -: #_inputdatawidth]} 
                                          ) : '0;
      @M4_OUT_STAGE
         $_outvalid = $actvalid;
         $_out[#_inputdatawidth-1:0] = $out_act;
   
   m4_popdef(['m4_pipenum'])
   m4_popdef(['M4_FETCH_STAGE'])
   m4_popdef(['M4_MUL_STAGE'])
   m4_popdef(['M4_SUM_STAGE'])
   m4_popdef(['M4_ACT_STAGE'])
   m4_popdef(['M4_OUT_STAGE'])
   

//Laeyer - Architecture of Layer
//parameter : /_top             -> top scope for Layer
//            /_layer           -> scope for layer
//            /_layerhier       -> scope for layer replication (i.e. hierarchy)
//            /_neuron       -> scope for _neuron
//            /_biasmem         -> scope for bias memory
//            /_weightmem       -> scope of weight memory
//            #_layernum        -> Indicates layer no.
//            #_numneuron       -> Indicates the number of neuron present in this layer
//            #_pipedepth       -> No. of Pipeline depth in neuron (presently supports only 5 cofiguration with max 4-cycle of depth)
//            #_numinputweights -> No. of input weights(i.e. previous layer's neuronnum) to this neuron.          
//            #_inputdatawidth  -> inputDataWidth
//            #_weightintwidth  -> weight int value(because of fixed point format) 
//            $_reset           -> external reset
//            $_myinput         -> input data to all neurons in layer at once (1-by-1)
//            $_myinputvalid    -> input data valid
//            $_out             -> output from layer
//            $_outvalid        -> 1-cycle output valid
\TLV layer(/_top, /_layer, /_layerhier, /_neuron, /_biasmem, /_weightmem, #_layernum, #_numneuron, #_pipedepth , #_numinputweights, #_inputdatawidth, #_weightintwidth, $_reset, $_myinput, $_myinputvalid, $_out, $_outvalid)
   m4_pushdef(['m4_layerhier'], m4_strip_prefix(/_layerhier))
   m4_pushdef(['m4_pipenum'], #_pipedepth)
   m4_default(['m4_pipenum'], 1)
   m4_case(m4_pipenum, 1, ['
   m4_pushdef(['m4_fetch_stage'],0)
   m4_pushdef(['m4_out_stage'],0)
   '], 2, ['
   m4_pushdef(['m4_fetch_stage'],0)
   m4_pushdef(['m4_out_stage'],1)
   '], 3, ['
   m4_pushdef(['m4_fetch_stage'],0)
   m4_pushdef(['m4_out_stage'],2)
   '], 4, ['
   m4_pushdef(['m4_fetch_stage'],0)
   m4_pushdef(['m4_out_stage'],3)
   '], 5, ['
   m4_pushdef(['m4_fetch_stage'],0)
   m4_pushdef(['m4_out_stage'],4)
   ']
   )
   /_layer
      @m4_fetch_stage
         $reset = /_top<>0$_reset; 
         $myinputvalid = /_top$_myinputvalid;
         //$myinput[#_inputdatawidth - 1:0] = /_top$_myinput[#_inputdatawidth - 1:0];
      /_layerhier[m4_eval(#_numneuron - 1):0]
         m4_pushdef(['m4_neuronnum'], #m4_layerhier)
         m4+neuron(/_top/_layer, /_neuron, /_biasmem, /_weightmem, #_layernum, m4_neuronnum, #_pipedepth, #_numinputweights, #_inputdatawidth, #_weightintwidth, $reset, $myinput, $myinputvalid, $out, $outvalid)
         @0
            $test[31:0] = m4_neuronnum;
            `BOGUS_USE($test)
         m4_popdef(['m4_neuronnum'])
      @m4_out_stage
         $_out[(#_numneuron * #_inputdatawidth) - 1:0] = /_layerhier[*]/_neuron$out;
         $_outvalid[(#_numneuron) - 1:0] = /_layerhier[*]/_neuron$outvalid;
   
   m4_popdef(['m4_layernum'])
   m4_popdef(['m4_pipenum'])
   m4_popdef(['m4_fetch_stage'])
   m4_popdef(['m4_out_stage'])
   
\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   \viz_js
      box: {strokeWidth: 0, left: -100, top: -75, width: 550, height: 1400, fill: "#BBBBBB"},
         init() {
            let widgets = {}
            widgets.title = new fabric.Text("Neural Network Architecture", {
                  left: 180, top: -50,
                  originX: "center",
                  fontSize: 22, fontFamily: "Courier New", fontWeight: "bold"
            })
            widgets.input = new fabric.Text("Input", {
                 left: -80, top: 520,
                 fontSize: 20, fontFamily: "Courier New",
            })
            return widgets
         }
   |pipe1
      @0
         $reset = *reset;
         $cnt[\$clog2(M4_NUMWEIGHT_LAYER1) : 0] = $reset ? '0 : 
                                        >>1$cnt + 1;
         $myinputvalid1 = (($cnt >= 1) && ($cnt <=  M4_NUMWEIGHT_LAYER1));
         \viz_js
            //template: {dot: ["Circle", {radius: 30, fill: "red"}]},
            box: {strokeWidth: 0, left: 20, top: 35, width: 50, height: 400},
            init() {
               let widgets = {}
               widgets.title = new fabric.Text("Layer 1", {
                     left: 50, top: 0,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
               })
               return widgets
            }
         
      //m4+neuron(|pipe, /neuron, /biasmem, /weightmem, 0, 0, 5, M4_NUMWEIGHT, M4_INPUTDATAWIDTH, M4_WEIGHTINTWIDTH, $reset, $myinput, $myinputvalid, $out, $outvalid)
      m4+layer(|pipe1, /layer1, /layernum1, /neuron1, /biasmem1, /weightmem1, 0, 30, 5, M4_NUMWEIGHT_LAYER1, M4_INPUTDATAWIDTH, M4_WEIGHTINTWIDTH, $reset, $myinput1, $myinputvalid1, $out1, $outvalid1)
      
      @4
         /layer1
            /layernum1[29:0]
               \viz_js
                  layout: "vertical",
                  box: {top: 30, left: 40, strokeWidth: 0, width: 40, height: 40},
                  render() {
                     let num = '/neuron1$out'.asInt()*15
                     return [
                        new fabric.Circle({
                           radius: 10,
                           fill: `rgb(${num}, 0, 0)`,
                           style: {
                              margin: 2
                           }
                        }),
                     ]
                  },
                  where: {top: 80, left: 80},
   
   |pipe2
      @0
         $ANY = /top|pipe1/layer1>>4$ANY;
         $count_layer1[\$clog2(30) : 0] = (/top|pipe1<>0$reset | (>>1$count_layer1 == M4_NUMWEIGHT_LAYER1)) ? '0 :
                                          ($outvalid1[0] & ! >>1$outvalid1[0]) ? 1 :
                                          (>>1$count_layer1 >= 1) ? >>1$count_layer1 + 1'b1 : $RETAIN;
         $holddata1[m4_eval(M4_NUMWEIGHT_LAYER1 * M4_INPUTDATAWIDTH) - 1:0] = (/top|pipe1<>0$reset | (>>1$count_layer1 == M4_NUMWEIGHT_LAYER1)) ? '0 :
                                    ($outvalid1[0] & ! >>1$outvalid1[0]) ? $out1 :
                                    (>>1$count_layer1 >= 1) ? (>>1$holddata1 >> M4_INPUTDATAWIDTH) : $RETAIN;
         
         $myinput2[M4_INPUTDATAWIDTH - 1:0] = $holddata1[M4_INPUTDATAWIDTH - 1:0];
         $myinputvalid2 = (/top|pipe1<>0$reset | (>>1$count_layer1 == M4_NUMWEIGHT_LAYER1)) ? '0 :
                           ($outvalid1[0] & ! >>1$outvalid1[0]) ? 1'b1 :
                           (>>1$count_layer1 >= 1) ? 1'b1 : $RETAIN;
         \viz_js
            box: {strokeWidth: 0, left: 150, top: 35, width: 50, height: 400},
            init() {
               let widgets = {}
               widgets.title = new fabric.Text("Layer 2", {
                     left: 170, top: 0,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
               })
               return widgets
            }
      m4+layer(|pipe2, /layer2, /layernum2, /neuron2, /biasmem2, /weightmem2, 1, 30, 5, M4_NUMWEIGHT_LAYER2, M4_INPUTDATAWIDTH, M4_WEIGHTINTWIDTH, $reset, $myinput2, $myinputvalid2, $out2, $outvalid2)
      
      @4
         /layer2
            /layernum2[29:0]
               \viz_js
                  layout: "vertical",
                  box: {top: 30, left: 0, strokeWidth: 0, width: 40, height: 40},
                  render() {
                     let num = '/neuron2$out'.asInt()*15
                     return [
                        new fabric.Circle({
                           radius: 10,
                           fill: `rgb(${num}, 0,0)`,
                        })
                     ]
                  },
                  where: {top: 80, left: 160},
      
      
      @4
         /layer2
            /layernum2[29:0]
               \viz_js
                  layout: {top: 0, left: 0}
               /layernum1[29:0]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {top: 40, left: 0},
                     render(){
                        let valr = '/layernum2/neuron2$out'.asInt()*10
                        let valg = '/top|pipe1/layer1/layernum1/neuron1$out'.asInt()*3
                        console.log(valg)
                        return [new fabric.Line([
                           0, 0, 100,
                           (this.getIndex("layernum2") - this.getIndex("layernum1")) * 40],
                           {stroke: `rgb(${valr},  ${valg}, 0)`, strokeWidth: 3})
                        ]
                     },
                     where: {top: 60, left: 60},
      
   |pipe3
      @0
         $ANY = /top|pipe2/layer2>>4$ANY;
         $count_layer2[\$clog2(M4_NUMWEIGHT_LAYER2) : 0] = (/top|pipe1<>0$reset | (>>1$count_layer2 == M4_NUMWEIGHT_LAYER2)) ? '0 :
                                          ($outvalid2[0] & ! >>1$outvalid2[0]) ? 1 :
                                          (>>1$count_layer2 >= 1) ? >>1$count_layer2 + 1'b1 : $RETAIN;
         $holddata2[m4_eval(M4_NUMWEIGHT_LAYER2 * M4_INPUTDATAWIDTH) - 1:0] = (/top|pipe1<>0$reset | (>>1$count_layer2 == M4_NUMWEIGHT_LAYER2)) ? '0 :
                                    ($outvalid2[0] & ! >>1$outvalid2[0]) ? $out2 :
                                    (>>1$count_layer2 >= 1) ? (>>1$holddata2 >> M4_INPUTDATAWIDTH) : $RETAIN;
         
         $myinput3[M4_INPUTDATAWIDTH - 1:0] = $holddata2[M4_INPUTDATAWIDTH - 1:0];
         $myinputvalid3 = (/top|pipe1<>0$reset | (>>1$count_layer2 == M4_NUMWEIGHT_LAYER2)) ? '0 :
                           ($outvalid2[0] & ! >>1$outvalid2[0]) ? 1'b1 :
                           (>>1$count_layer2 >= 1) ? 1'b1 : $RETAIN;
         \viz_js
            box: {strokeWidth: 0, left: 290, top: 35, width: 50, height: 400},
            init() {
               let widgets = {}
               widgets.title = new fabric.Text("Layer 3", {
                     left: 320, top: 0,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
               })
               return widgets
            }
      m4+layer(|pipe3, /layer3, /layernum3, /neuron3, /biasmem3, /weightmem3, 2, 30, 5, M4_NUMWEIGHT_LAYER3, M4_INPUTDATAWIDTH, M4_WEIGHTINTWIDTH, $reset, $myinput3, $myinputvalid3, $out3, $outvalid3)
      
      @4
         /layer3
            /layernum3[29:0]
               \viz_js
                  layout: "vertical",
                  box: {top: 30, left: 100, strokeWidth: 0, width: 40, height: 40},
                  render() {
                     let $valid = '/neuron3$outvalid'.asInt()
                     let num = '/neuron3$out'.asInt()*10
                     return [
                        new fabric.Circle({
                           radius: 10,
                           fill: `rgb(${num}, 0, 0)`,
                           style: {
                              margin: 2
                           }
                        }),
                     ]
                  },
                  where: {top: 80, left: 400},
      
      @5
         /layer3
            /layernum3[29:0]
               \viz_js
                  layout: {top: 0, left: 0}
               /layernum2[29:0]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {top: 40, left: 0},
                     render(){
                        let valr = '/layernum3/neuron3$out'.asInt()*10
                        let valg = '/top|pipe2/layer2/layernum2/neuron2$out'.asInt()*3
                        return [new fabric.Line([
                           0, 0, 120, 
                           (this.getIndex("layernum3") - this.getIndex("layernum2")) * 40],
                           {stroke: `rgb(${valr}, ${valg}, 0)`, strokeWidth: 3})
                        ]
                     },
                     where: {top: 60, left: 180},
   
   |pipe
      @0
         $result[m4_eval(30 * M4_INPUTDATAWIDTH)-1:0] = /top|pipe3/layer3>>4$out3;
         $resultvalid = /top|pipe3/layer3>>4$outvalid3;
         \viz_js
            box: {strokeWidth: 0},
            
            init() {
               let widgets = {}
               widgets.title = new fabric.Text("Output", {
                     left: 400, top: 520,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
               })
               widgets.layer_name = new fabric.Text("Hidden Layers", {
                     left: 170, top: 1250,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
               })
               return widgets
            }
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 200;
   *failed = 1'b0;
\SV
   endmodule
