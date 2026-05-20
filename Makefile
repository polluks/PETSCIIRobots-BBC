CA65 := ca65
LD65 := ld65
CFG  := cfg/bbc-mode7.cfg
TARGET := robots

all: $(TARGET)

$(TARGET): src/robots.o
	$(LD65) -C $(CFG) -o $(TARGET) $^ -m $(TARGET).map

src/robots.o: src/robots.s inc/bbc.inc
	$(CA65) --include-dir inc -t none -o $@ $<

clean:
	rm -f src/*.o $(TARGET) $(TARGET).map
