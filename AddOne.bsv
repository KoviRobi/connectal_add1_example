import FIFO::*;

typedef Bit#(64) DataT;

interface Add1Request;
  method Action add1(DataT n);
endinterface

interface AddOne;
  interface Add1Request request;
endinterface
interface Add1Response;
  method Action getResult(DataT n_plus_1);
endinterface


module mkAddOne#(Add1Response response)(AddOne);
  FIFO#(DataT) incoming <- mkFIFO;
  FIFO#(DataT) outgoing <- mkFIFO;
 
  rule add1;
    outgoing.enq(incoming.first + 1);
    incoming.deq;
  endrule

  rule response;
    response.getResult(outgoing.first);
    outgoing.deq;
  endrule

  interface Add1Request request;
    method Action add1(DataT n);
      incoming.enq(n);
    endmethod
  endinterface

endmodule

