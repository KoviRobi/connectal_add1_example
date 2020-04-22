To just test out in simulation, do
```sh
$ nix-shell # to set things up correctly
$ make add1_single_threaded # if the directory add1_single_threaded doesn't exist
$ cd add1_single_threaded
$ make build.bluesim
$ ./bluesim/bin/ubuntu.exe <number>
```

The `*.html` files are generate from the `*.lit` files, so are the source
files.

# Simple incrementer example
## Single-threaded
### Overview
This describes a simple increment FPGA 'service'. The BlueSpec part of the
service is:
```bsv
import FIFO::*;

typedef Bit#(64) DataT;

@{Interfaces}

module mkAddOne#(Add1Response response)(AddOne);
  FIFO#(DataT) incoming <- mkFIFO;
  FIFO#(DataT) outgoing <- mkFIFO;
 
  rule add1;
    outgoing.enq(incoming.first + 1);
    incoming.deq;
  endrule

  @{Take data off `outgoing`}
  @{Put data onto `incoming`}
endmodule
```
The module name must be 'mk' plus the file-name, the interface name must also
be the same as the file-name, i.e. 'AddOne', and is what is used to call from
software into hardware. The parameter of the module, 'Add1Response response' is
what is used to call back from hardware into software.

We need to add this file to the Makefile, and also load the Connectal makefile.

```Makefile
CONNECTALDIR ?= ./connectal # path to git checkout of Connectal

@{Software to hardware calls}
@{Hardware to software calls}

BSVFILES = AddOne.bsv
CPPFILES = send_number.cpp

include $(CONNECTALDIR)/Makefile.connectal
```

As you can imagine, `send_number.cpp` sends a number to the hardware.
```cpp
#include <iostream> // std::cout, std::cerr,  std::endl
#include <cstdlib>  // sdt::exit, std::atoi

#include "GeneratedTypes.h" // DataT
@{C++ Includes}

@{Hardware response object}

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "Expecting one argument, the number to send" << std::endl;
    std::exit(1);
  }
  DataT send = atoi(argv[1]);

  @{C++ Initialisation}

  @{Send the number from `send`}

  DataT responseValue;
  @{Wait for the response, put it into `responseValue`}

  std::cout << "Received: " << responseValue;
  return 0;
}
```

### Software to hardware
To send data from the software to the hardware, we need to declare the BlueSpec
interface to do this. Remember, this is the `AddOne` interface argument to the
`mkAddOne` module, and must be the same name as the file.
```bsv
interface Add1Request;
  method Action add1(DataT n);
endinterface

interface AddOne;
  interface Add1Request request;
endinterface
```

Then we tell Connectal of this interface, via the Makefile. This is a
space-separated list of pairs. Each pair is of the form
`software-interface:hardware-interface`.
```Makefile
S2H_INTERFACES = Add1Request:AddOne.request
```
The software-interface part should also be a BlueSpec interface, as Connectal
parses the BSV file for it, and generates the C++ class based on it.

The hardware-interface part is where to look for the software-interface inside
the main `AddOne` interface.

Based on this, Connectal generates a proxy class which supports the `add1`
call, and the C++ header file for this is based off the software-interface
name. If you want to inspect it, it is in `\${BOARD}/bluesim/jni/` where
`\${BOARD}` is e.g. `bluesim` when calling `make gen.bluesim` (note, `make
build.bluesim` automatically does the `gen.bluesim` make target).

```cpp
#include "Add1Request.h" // Add1RequestProxy
```

To use this proxy object in C++, we need to create it and then we can call the
`add1` method on it. The `IfcNames_Add1RequestS2H` is part of the `IfcNames`
enum from `\${BOARD}/bluesim/jni/topEnum.h`.

```cpp
Add1RequestProxy *requestProxy = new Add1RequestProxy(IfcNames_Add1RequestS2H);
```

```cpp
std::cout << "Sending: " << send << std::endl;
requestProxy->add1(send);
```

Then in BlueSpec land, to receive this number from the software, remember that
the `mkAddOne` module/`AddOne` interface contains the `Add1Request` interface
which has the `add1` method. This is what the software calls, and what we must
implement.

```bsv
interface Add1Request request;
  method Action add1(DataT n);
    incoming.enq(n);
  endmethod
endinterface
```

That's it from the software to hardware side.

### Hardware to software

Calling from hardware into software is a bit more complicated, because the
software application is currently single-threaded, so we have to manually check
if we have received anything back from the hardware.

But first, in the BlueSpec file and the Makefile there is a similar declaration
of the communication interface.

```bsv
interface Add1Response;
  method Action getResult(DataT n_plus_1);
endinterface
```

The syntax of `H2S_INTERFACES` is similar to `S2H_INTERFACES`, except it is a
space-separated list of `hardware-interface:software-interface` instead.

```Makefile
H2S_INTERFACES = AddOne:Add1Response
```

The hardware-interface part is still the argument to the `mkAddOne` module, but
the software-interface part is the parameter to the `mkAddOne` module. And
similarly, there is a C++ header file generated based on the parsed BlueSpec
interface.

```cpp
#include "Add1Response.h" // Add1ResponseWrapper
#include "portal.h" // PortalPoller
```

Though this time, it's not the generated proxy object that we are interested
in, but the abstract wrapper object that the hardware will 'call'. Remember
that due to the single-threaded nature of this program, we will need to check
for this call by polling, so we need to initialise a `PortalPoller` (previously
there were the `portalExec_start`, `portalExec_poll` and `portalExec_event`
functions, these are longer but you might still see them mentioned in old
documentation or the [Connectal
paper](http://www.connectal.org/connectal-fpga2015.pdf))

```cpp
PortalPoller *poller = new PortalPoller();
Add1Response response(IfcNames_Add1ResponseH2S);
```

```cpp
while (!response.hasReceived()) {
  poller->event();
}
response.clearReceived();
```

The response object only needs to implement the `getResult` method, but so that
we don't poll forever, it also has a flag to indicate if polling resulted in a
response
```cpp
class Add1Response : public Add1ResponseWrapper {
  private: 
    bool received = false;

  public:
    Add1Response(int id) : Add1ResponseWrapper(id) { }

    void getResult(const DataT n_plus_1) override {
      std::cout << "Received: " << n_plus_1 << std::endl;
      received = true;
    }

    bool hasReceived() { return received; }
    void clearReceived() { received = false; }
};
```

And the hardware calls the software when there is any outgoing data.
```bsv
rule response;
  response.getResult(outgoing.first);
  outgoing.deq;
endrule
```

### Trying it out with BlueSim
To try this out, you should do `make build.bluesim`, and then you can execute
`./bluesim/bin/ubuntu.exe <number>`.
