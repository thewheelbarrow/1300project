#everyone say thank you claude

# Run `make` on the Pi from the repo root.
# Prerequisites on the Pi: RF24 library installed, g++/build-essential, Odin.
 
CXX      ?= g++
AR       ?= ar
CXXFLAGS ?= -O2 -Wall -Wextra
 
# Output binary name (change to your project name).
BIN       ?= vrenhance
# Extra flags for odin, e.g. -o:speed or -debug.
ODINFLAGS ?=
 
SHIM_DIR := rf24
SHIM_LIB := $(SHIM_DIR)/librf24shim.a
 
.PHONY: all clean
 
# The shim is only rebuilt when shim.cpp changes; odin does its own caching.
all: $(SHIM_LIB)
	odin build . -out:$(BIN) $(ODINFLAGS)
 
$(SHIM_DIR)/shim.o: $(SHIM_DIR)/shim.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@
 
$(SHIM_LIB): $(SHIM_DIR)/shim.o
	$(AR) rcs $@ $<
 
clean:
	rm -f $(SHIM_DIR)/shim.o $(SHIM_LIB) $(BIN)
 