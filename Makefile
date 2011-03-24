COMPILER = dmd
COMPILER_FLAGS = -w -O -release

.PHONY: all clean
.SUFFIXES: .d .o

OBJS = main.o
EXECUTABLE = quarkd

.d.o:
	$(COMPILER) $(COMPILER_FLAGS) -c -of$@ $<

$(EXECUTABLE): $(OBJS)
	$(COMPILER) $(COMPILER_FLAGS) -of$(EXECUTABLE) $(OBJS)

clean:
	rm -f $(OBJS) $(EXECUTABLE)
