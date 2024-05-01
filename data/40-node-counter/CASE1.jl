# NETWORK
WDW_NODES = [i for i in 1:29]
SNG_NODES = [1,2,3]
SH2_NODES = [4,5,6]
NODES = [i for i in 1:40]
EDGES = [i for i in 1:39]
COMPRESSORS = [i for i in 1:6]

# PARAMETERS
G_MAX_OP = 1600         # max demand at optimized node
OP_NODE = "NA"          # optimized node
CONC_MIN = "NA"         # min conc at withdrawal INACTIVE!
CARBON_OFFSET = 0.055
BIDPRICE = 0.019
BIDPRICEX = BIDPRICE       