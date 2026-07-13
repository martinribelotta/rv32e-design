#!/bin/bash
# Setup script para QuestaSim/ModelSim con Intel Quartus
# Este script configura el entorno para usar Questa con RV32E

set -e

echo "=== Setup QuestaSim/ModelSim ==="

# Detectar instalación de Intel Quartus
if [ -d "/opt/intelFPGA" ]; then
    echo "Found Intel Quartus at /opt/intelFPGA"
    export QUARTUS_ROOTDIR="/opt/intelFPGA"
elif [ -d "$HOME/intelFPGA" ]; then
    echo "Found Intel Quartus at $HOME/intelFPGA"
    export QUARTUS_ROOTDIR="$HOME/intelFPGA"
else
    echo "Warning: Intel Quartus not found in standard locations"
    echo "Please set QUARTUS_ROOTDIR manually"
fi

# Configurar Questa
if [ -d "$QUARTUS_ROOTDIR/questa_sim" ]; then
    echo "Found Questa at $QUARTUS_ROOTDIR/questa_sim"
    export QUESTA_HOME="$QUARTUS_ROOTDIR/questa_sim"
    export PATH="$QUESTA_HOME/lnx86_64:$PATH"
elif [ -d "$QUARTUS_ROOTDIR/modelsim_ase" ]; then
    echo "Found ModelSim at $QUARTUS_ROOTDIR/modelsim_ase"
    export QUESTA_HOME="$QUARTUS_ROOTDIR/modelsim_ase"
    export PATH="$QUESTA_HOME/lnx86_64:$PATH"
else
    echo "Warning: Questa/ModelSim not found in Quartus installation"
    echo "Looking for standalone Questa..."
    
    # Buscar Questa standalone
    if [ -d "/opt/questasim" ]; then
        export QUESTA_HOME="/opt/questasim"
        export PATH="$QUESTA_HOME/lnx86_64:$PATH"
    elif [ -d "/opt/mentor" ]; then
        export QUESTA_HOME="/opt/mentor"
        export PATH="$QUESTA_HOME/lnx86_64:$PATH"
    fi
fi

# Verificar Questa
if command -v vsim &> /dev/null; then
    echo "Found vsim:"
    vsim -version | head -3
else
    echo "Warning: vsim not in PATH"
    echo "Run this script after installing QuestaSim"
    echo "Or add to your ~/.bashrc:"
    echo '  export PATH="/path/to/questa/lnx86_64:$PATH"'
    exit 1
fi

# Configurar UVM
if [ -z "$UVM_HOME" ]; then
    # Buscar UVM instalado con Questa
    if [ -d "$QUESTA_HOME/verilog_src/uvm-1.2" ]; then
        export UVM_HOME="$QUESTA_HOME/verilog_src/uvm-1.2"
    elif [ -d "$QUESTA_HOME/verilog_src/uvm-1.1" ]; then
        export UVM_HOME="$QUESTA_HOME/verilog_src/uvm-1.1"
    else
        echo "Warning: UVM not found in Questa installation"
        echo "You may need to install UVM separately"
    fi
fi

echo ""
echo "=== Setup Complete ==="
echo "SIMULATOR: $SIMULATOR (default: questa)"
echo "QUESTA_HOME: $QUESTA_HOME"
echo "UVM_HOME: ${UVM_HOME:-not set}"
echo ""
echo "Para usar: make SIMULATOR=questa"
echo "Para UVM: make SIMULATOR=questa UVM_TEST=rv32e_alu_test"
echo ""

# Guardar variables de entorno para uso posterior
cat > .questa_env << EOF
export QUESTA_HOME=$QUESTA_HOME
export UVM_HOME=${UVM_HOME:-}
export SIMULATOR=questa
EOF

echo "Environment saved to .questa_env"
echo "Source it with: source .questa_env"
