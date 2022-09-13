#!/bin/sh

WORKSPACE_PATH=${WORKSPACE_PATH:-""}

if [ -z "$WORKSPACE_PATH" ]; then
  echo "Missing WORKSPACE_PATH."
  exit 1
fi

errors=$(cat errors.txt)
keys=$(cat keys.txt)
keysImports=$(cat keys_imports.txt)
expectedBankKeeperMethods=$(cat expected_bank_keeper_methods.txt)
fullGame=$(cat full_game.txt)
storedGameInFifo=$(cat stored_game_in_fifo.txt)
wagerHandler=$(cat wager_handler.txt)
endBlockServerGame=$(cat end_block_server_game.txt)
msgServerCreateGame=$(cat msg_server_create_game.txt)
msgServerPlayMove=$(cat msg_server_play_move.txt)
msgServerRejectGame=$(cat msg_server_reject_game.txt)
genesisNextGame=$(cat genesis_next_game.txt)

if [ -z "$errors" ] ||
  [ -z "$keys" ] ||
  [ -z "$keysImports" ] ||
  [ -z "$expectedBankKeeperMethods" ] ||
  [ -z "$fullGame" ] ||
  [ -z "$storedGameInFifo" ] ||
  [ -z "$wagerHandler" ] ||
  [ -z "$endBlockServerGame" ] ||
  [ -z "$msgServerCreateGame" ] ||
  [ -z "$msgServerPlayMove" ] ||
  [ -z "$msgServerRejectGame" ] ||
  [ -z "$genesisNextGame" ]; then

  echo "Missing necessary build files."
  exit 1
fi

mkdir -p "$WORKSPACE_PATH" && cd "$WORKSPACE_PATH" || exit

printf "\n\n==================== Scaffold chain ====================\n"
ignite scaffold chain github.com/anonymous/checkers && cd checkers || exit
ignite scaffold single nextGame idValue:uint fifoHead fifoTail --module checkers --no-message --yes
ignite scaffold map storedGame game turn red black moveCount:uint beforeId afterId deadline winner wager:uint --module checkers --no-message --yes
ignite scaffold message createGame red black wager:uint --module checkers --response idValue --yes
ignite scaffold message playMove idValue fromX:uint fromY:uint toX:uint toY:uint --module checkers --response idValue,capturedX:int,capturedY:int,winner --yes
ignite scaffold message rejectGame idValue --module checkers --yes

printf "\n\n==================== Fetch checkers rules ====================\n"
mkdir x/checkers/rules
curl https://raw.githubusercontent.com/batkinson/checkers-go/a09daeb1548dd4cc0145d87c8da3ed2ea33a62e3/checkers/checkers.go | sed 's/package checkers/package rules/' >x/checkers/rules/checkers.go

printf "\n\n==================== Update checkers module files ====================\n"
echo "$errors" >>x/checkers/types/errors.go

echo "$keys" >>x/checkers/types/keys.go

sed -i'' -e "2s/^/\n$keysImports\n/" x/checkers/types/keys.go
rm x/checkers/types/keys.go-e

BANK_KEEPER_METHOD_MARK="\/\/ Methods imported from bank should be defined here"
sed -i'' -e "s/$BANK_KEEPER_METHOD_MARK/$expectedBankKeeperMethods\n\t$BANK_KEEPER_METHOD_MARK/" x/checkers/types/expected_keepers.go
rm x/checkers/types/expected_keepers.go-e

KEEPER_STRUCT_PREFIX="Keeper struct {"
KEEPER_FUNCTION_PREFIX="func NewKeeper("
KEEPER_INSTANCE_RETURN_PREFIX="return \&Keeper{"
BANK_KEEPER_PARAMETER="bank types.BankKeeper"
sed -i'' -e "s/$KEEPER_STRUCT_PREFIX/$KEEPER_STRUCT_PREFIX\n\t\t$BANK_KEEPER_PARAMETER/" x/checkers/keeper/keeper.go
sed -i'' -e "s/$KEEPER_FUNCTION_PREFIX/$KEEPER_FUNCTION_PREFIX\n\t$BANK_KEEPER_PARAMETER,/" x/checkers/keeper/keeper.go
sed -i'' -e "s/$KEEPER_INSTANCE_RETURN_PREFIX/$KEEPER_INSTANCE_RETURN_PREFIX\n\t\tbank: bank,/" x/checkers/keeper/keeper.go
rm x/checkers/keeper/keeper.go-e

echo "$fullGame" >x/checkers/types/full_game.go
echo "$storedGameInFifo" >x/checkers/keeper/stored_game_in_fifo.go
echo "$wagerHandler" >x/checkers/keeper/wager_handler.go
echo "$endBlockServerGame" >x/checkers/keeper/end_block_server_game.go

echo "$msgServerCreateGame" >x/checkers/keeper/msg_server_create_game.go
echo "$msgServerPlayMove" >x/checkers/keeper/msg_server_play_move.go
echo "$msgServerRejectGame" >x/checkers/keeper/msg_server_reject_game.go

sed -i'' -e "s/NextGame:[ ]*nil,/$genesisNextGame/" x/checkers/types/genesis.go
rm x/checkers/types/genesis.go-e

END_BLOCK_PREFIX="func (am AppModule) EndBlock("
END_BLOCK_SUFFIX=" sdk.Context, _ abci.RequestEndBlock) \[\]abci.ValidatorUpdate {"
END_BLOCK_CONTENT="am.keeper.ForfeitExpiredGames(sdk.WrapSDKContext(ctx))"
sed -i'' -e "s/${END_BLOCK_PREFIX}_${END_BLOCK_SUFFIX}/${END_BLOCK_PREFIX}ctx${END_BLOCK_SUFFIX}\n\t${END_BLOCK_CONTENT}/" x/checkers/module.go
rm x/checkers/module.go-e

CHECKERS_KEEPER_INITIALIZE="app.CheckersKeeper = \*checkersmodulekeeper.NewKeeper("
MACC_PERMS_PREFIX="maccPerms = map\[string\]\[\]string{"
sed -i'' -e "s/$CHECKERS_KEEPER_INITIALIZE/$CHECKERS_KEEPER_INITIALIZE\n\t\tapp.BankKeeper,/" app/app.go
sed -i'' -e "s/$MACC_PERMS_PREFIX/$MACC_PERMS_PREFIX\n\t\tcheckersmoduletypes.ModuleName: nil,/" app/app.go
rm app/app.go-e





