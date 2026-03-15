#!/usr/bin/env python3
import sys

def add_addresses_function(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    
    addresses_func = """
    function addresses() public view returns (
        address aes_,
        address usdt_,
        address pair_,
        address factory_,
        address router_,
        address attacker_
    ) {
        return (aesAddr, usdtAddr, pairAddr, factoryAddr, routerAddr, attacker);
    }

"""
    
    # Find the end of setUp function
    new_lines = []
    in_setup = False
    brace_count = 0
    added = False
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        
        if 'function setUp' in line:
            in_setup = True
            brace_count = 0
        
        if in_setup:
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0 and not added:
                new_lines.append(addresses_func)
                added = True
                in_setup = False
    
    with open(filename, 'w') as f:
        f.writelines(new_lines)
    print(f"Added addresses() to {filename}")

if __name__ == "__main__":
    add_addresses_function("benchmarks/AES/AES.t.sol")
