COMPILER = dmd
COMPILER_FLAGS = -w -wi -gc -gs# -unittest

.PHONY: all clean
.SUFFIXES: .d .o

OBJS = main.o quarkhttp/config.o quarkhttp/core.o quarkhttp/response_thread.o quarkhttp/server.o quarkhttp/utils.o
EXECUTABLE = quarkd

all: $(EXECUTABLE)

.d.o:
	$(COMPILER) $(COMPILER_FLAGS) -c -of$@ $<

$(EXECUTABLE): $(OBJS)
	$(COMPILER) $(COMPILER_FLAGS) -of$(EXECUTABLE) $(OBJS)

clean:
	rm -f $(OBJS) $(EXECUTABLE)
