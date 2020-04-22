CONNECTALDIR ?= ./connectal # path to git checkout of Connectal

S2H_INTERFACES = Add1Request:AddOne.request

H2S_INTERFACES = AddOne:Add1Response


BSVFILES = AddOne.bsv
CPPFILES = send_number.cpp

include $(CONNECTALDIR)/Makefile.connectal

