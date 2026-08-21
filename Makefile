CA65 := ca65
LD65 := ld65
PYTHON := python3

# BBC Micro target
BBC_CFG  := cfg/bbc-mode7.cfg
BBC_TARGET := robots
BBC_SSD := $(BBC_TARGET).ssd

# Electron target
ELK_CFG  := cfg/electron.cfg
ELK_TARGET := robots_e
ELK_UEF := $(ELK_TARGET).uef

all: $(BBC_TARGET)

# --- BBC Micro ---
$(BBC_TARGET): src/robots.o
	$(LD65) -C $(BBC_CFG) -o $@ $^ -m $(BBC_TARGET).map

src/robots.o: src/robots.s inc/bbc.inc
	$(CA65) --include-dir inc -t none -o $@ $<

ssd: $(BBC_SSD)

$(BBC_SSD): $(BBC_TARGET) mkssd.py
	$(PYTHON) mkssd.py $(BBC_TARGET) $@ 1900 1900 3

# --- Acorn Electron ---
$(ELK_TARGET): src/robots_e.o
	$(LD65) -C $(ELK_CFG) -o $@ $^ -m $(ELK_TARGET).map

src/robots_e.o: src/robots_e.s inc/electron.inc
	$(CA65) --include-dir inc -t none -o $@ $<

uef: $(ELK_UEF)

$(ELK_UEF): $(ELK_TARGET) mkssd.py
	$(PYTHON) mkssd.py $(ELK_TARGET) $@ 0E00 0E00 --uef

clean:
	rm -f src/*.o $(BBC_TARGET) $(BBC_TARGET).map $(ELK_TARGET) $(ELK_TARGET).map *.ssd *.uef
