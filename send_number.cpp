#include <iostream> // std::cout, std::cerr,  std::endl
#include <cstdlib>  // sdt::exit, std::atoi

#include "GeneratedTypes.h" // DataT
#include "Add1Request.h" // Add1RequestProxy
#include "Add1Response.h" // Add1ResponseWrapper
#include "portal.h" // PortalPoller


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


int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "Expecting one argument, the number to send" << std::endl;
    std::exit(1);
  }
  DataT send = atoi(argv[1]);

  Add1RequestProxy *requestProxy = new Add1RequestProxy(IfcNames_Add1RequestS2H);
  PortalPoller *poller = new PortalPoller();
  Add1Response response(IfcNames_Add1ResponseH2S);


  std::cout << "Sending: " << send << std::endl;
  requestProxy->add1(send);


  DataT responseValue;
  while (!response.hasReceived()) {
    poller->event();
  }
  response.clearReceived();


  std::cout << "Received: " << responseValue;
  return 0;
}

