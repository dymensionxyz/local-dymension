# Build the checkers module
More details from [here](https://tutorials.cosmos.network/academy/3-my-own-chain/stored-game.html)

Add checkers rules
```sh
mkdir x/checkers/rules
curl https://raw.githubusercontent.com/batkinson/checkers-go/a09daeb1548dd4cc0145d87c8da3ed2ea33a62e3/checkers/checkers.go | sed 's/package checkers/package rules/' > x/checkers/rules/checkers.go
```
Scaffold the following types:
```sh
ignite scaffold single nextGame idValue:uint fifoHead fifoTail --module checkers --no-message

ignite scaffold map storedGame game turn red black moveCount:uint beforeId afterId deadline winner wager:uint --module checkers --no-message

ignite scaffold message createGame red black wager:uint --module checkers --response idValue

ignite scaffold message playMove idValue fromX:uint fromY:uint toX:uint toY:uint --module checkers --response idValue,capturedX:int,capturedY:int,winner

ignite scaffold message rejectGame idValue --module checkers
```
Add errors to `x/checkers/types/errors.go`
```go
var (
    ErrInvalidRed              = sdkerrors.Register(ModuleName, 1101, "red address is invalid: %s")
    ErrInvalidBlack            = sdkerrors.Register(ModuleName, 1102, "black address is invalid: %s")
    ErrGameNotParseable        = sdkerrors.Register(ModuleName, 1103, "game cannot be parsed")
    ErrGameNotFound            = sdkerrors.Register(ModuleName, 1104, "game by id not found: %s")
    ErrCreatorNotPlayer        = sdkerrors.Register(ModuleName, 1105, "message creator is not a player: %s")
    ErrNotPlayerTurn           = sdkerrors.Register(ModuleName, 1106, "player tried to play out of turn: %s")
    ErrWrongMove               = sdkerrors.Register(ModuleName, 1107, "wrong move")
    ErrRedAlreadyPlayed        = sdkerrors.Register(ModuleName, 1108, "red player has already played")
    ErrBlackAlreadyPlayed      = sdkerrors.Register(ModuleName, 1109, "black player has already played")
    ErrInvalidDeadline         = sdkerrors.Register(ModuleName, 1110, "deadline cannot be parsed: %s")
    ErrGameFinished            = sdkerrors.Register(ModuleName, 1111, "game is already finished")
    ErrRedCannotPay            = sdkerrors.Register(ModuleName, 1112, "red cannot pay the wager")
    ErrBlackCannotPay          = sdkerrors.Register(ModuleName, 1113, "black cannot pay the wager")
    ErrCannotFindWinnerByColor = sdkerrors.Register(ModuleName, 1114, "cannot find winner by color: %s")
    ErrNothingToPay            = sdkerrors.Register(ModuleName, 1115, "there is nothing to pay, should not have been called")
    ErrCannotRefundWager       = sdkerrors.Register(ModuleName, 1116, "cannot refund wager to: %s")
    ErrCannotPayWinnings       = sdkerrors.Register(ModuleName, 1117, "cannot pay winnings to winner")
    ErrNotInRefundState        = sdkerrors.Register(ModuleName, 1118, "game is not in a state to refund, move count: %d")
)
```
Add keys to `x/checkers/types/keys.go`
```go
const (
    NoFifoIdKey     = "-1"
    MaxTurnDuration = time.Duration(5 * 60 * 1000_000_000) // 5 minutes
    DeadlineLayout  = "2006-01-02 15:04:05.999999999 +0000 UTC"
)
```
Update `BankKeeper` in `x/checkers/types/expected_keepers.go`
```go
type BankKeeper interface {
    SendCoinsFromModuleToAccount(ctx sdk.Context, senderModule string, recipientAddr sdk.AccAddress, amt sdk.Coins) error
    SendCoinsFromAccountToModule(ctx sdk.Context, senderAddr sdk.AccAddress, recipientModule string, amt sdk.Coins) error
}
```
Update `Keeper` struct and `NewKeeper` function in `x/checkers/keeper/keeper.go`
```go
type (
    Keeper struct {
        bank     types.BankKeeper
        ...
    }
)

func NewKeeper(
    bank types.BankKeeper,
    ...
) *Keeper {
    return &Keeper{
        bank:     bank,
        ...
    }
}
```
Create `x/checkers/types/full_game.go`
```go
func (storedGame *StoredGame) GetRedAddress() (red sdk.AccAddress, err error) {
    red, errRed := sdk.AccAddressFromBech32(storedGame.Red)
    return red, sdkerrors.Wrapf(errRed, ErrInvalidRed.Error(), storedGame.Red)
}

func (storedGame *StoredGame) GetBlackAddress() (black sdk.AccAddress, err error) {
    black, errBlack := sdk.AccAddressFromBech32(storedGame.Black)
    return black, sdkerrors.Wrapf(errBlack, ErrInvalidBlack.Error(), storedGame.Black)
}

func (storedGame *StoredGame) ParseGame() (game *rules.Game, err error) {
    game, errGame := rules.Parse(storedGame.Game)
    if errGame != nil {
        return nil, sdkerrors.Wrapf(errGame, ErrGameNotParseable.Error())
    }
    game.Turn = rules.StringPieces[storedGame.Turn].Player
    if game.Turn.Color == "" {
        return nil, sdkerrors.Wrapf(errors.New(fmt.Sprintf("Turn: %s", storedGame.Turn)), ErrGameNotParseable.Error())
    }
    return game, nil
}

func (storedGame *StoredGame) GetDeadlineAsTime() (deadline time.Time, err error) {
    deadline, errDeadline := time.Parse(DeadlineLayout, storedGame.Deadline)
    return deadline, sdkerrors.Wrapf(errDeadline, ErrInvalidDeadline.Error(), storedGame.Deadline)
}

func GetNextDeadline(ctx sdk.Context) time.Time {
    return ctx.BlockTime().Add(MaxTurnDuration)
}

func FormatDeadline(deadline time.Time) string {
    return deadline.UTC().Format(DeadlineLayout)
}

func (storedGame *StoredGame) GetPlayerAddress(color string) (address sdk.AccAddress, found bool, err error) {
    red, err := storedGame.GetRedAddress()
    if err != nil {
        return nil, false, err
    }
    black, err := storedGame.GetBlackAddress()
    if err != nil {
        return nil, false, err
    }
    address, found = map[string]sdk.AccAddress{
        rules.PieceStrings[rules.RED_PLAYER]:   red,
        rules.PieceStrings[rules.BLACK_PLAYER]: black,
    }[color]
    return address, found, nil
}

func (storedGame *StoredGame) GetWinnerAddress() (address sdk.AccAddress, found bool, err error) {
    address, found, err = storedGame.GetPlayerAddress(storedGame.Winner)
    return address, found, err
}

func (storedGame *StoredGame) GetWagerCoin() (wager sdk.Coin) {
    return sdk.NewCoin(sdk.DefaultBondDenom, sdk.NewInt(int64(storedGame.Wager)))
}

func (storedGame StoredGame) Validate() (err error) {
    _, err = storedGame.ParseGame()
    if err != nil {
        return err
    }
    _, err = storedGame.GetRedAddress()
    if err != nil {
        return err
    }
    _, err = storedGame.GetBlackAddress()
    return err
}
```
Create `x/checkers/keeper/stored_game_in_fifo.go`
```go
func (k Keeper) RemoveFromFifo(ctx sdk.Context, game *types.StoredGame, info *types.NextGame) {
    // Does it have a predecessor?
    if game.BeforeId != types.NoFifoIdKey {
        beforeElement, found := k.GetStoredGame(ctx, game.BeforeId)
        if !found {
            panic("Element before in Fifo was not found")
        }
        beforeElement.AfterId = game.AfterId
        k.SetStoredGame(ctx, beforeElement)
        if game.AfterId == types.NoFifoIdKey {
            info.FifoTail = beforeElement.Index
        }
        // Is it at the FIFO head?
    } else if info.FifoHead == game.Index {
        info.FifoHead = game.AfterId
    }
    // Does it have a successor?
    if game.AfterId != types.NoFifoIdKey {
        afterElement, found := k.GetStoredGame(ctx, game.AfterId)
        if !found {
            panic("Element after in Fifo was not found")
        }
        afterElement.BeforeId = game.BeforeId
        k.SetStoredGame(ctx, afterElement)
        if game.BeforeId == types.NoFifoIdKey {
            info.FifoHead = afterElement.Index
        }
        // Is it at the FIFO tail?
    } else if info.FifoTail == game.Index {
        info.FifoTail = game.BeforeId
    }
    game.BeforeId = types.NoFifoIdKey
    game.AfterId = types.NoFifoIdKey
}

// WARN It does not save game or info.
func (k Keeper) SendToFifoTail(ctx sdk.Context, game *types.StoredGame, info *types.NextGame) {
    if info.FifoHead == types.NoFifoIdKey && info.FifoTail == types.NoFifoIdKey {
        game.BeforeId = types.NoFifoIdKey
        game.AfterId = types.NoFifoIdKey
        info.FifoHead = game.Index
        info.FifoTail = game.Index
    } else if info.FifoHead == types.NoFifoIdKey || info.FifoTail == types.NoFifoIdKey {
        panic("Fifo should have both head and tail or none")
    } else if info.FifoTail == game.Index {
        // Nothing to do, already at tail
    } else {
        // Snip game out
        k.RemoveFromFifo(ctx, game, info)
    
        // Now add to tail
        currentTail, found := k.GetStoredGame(ctx, info.FifoTail)
        if !found {
            panic("Current Fifo tail was not found")
        }
        currentTail.AfterId = game.Index
        k.SetStoredGame(ctx, currentTail)
    
        game.BeforeId = currentTail.Index
        info.FifoTail = game.Index
    }
}
```
Create `x/checkers/keeper/wager_handler.go`
```go
// Returns an error if the player has not enough funds.
func (k *Keeper) CollectWager(ctx sdk.Context, storedGame *types.StoredGame) error {
    // Make the player pay the wager at the beginning
    if storedGame.MoveCount == 0 {
        // Black plays first
        black, err := storedGame.GetBlackAddress()
        if err != nil {
            panic(err.Error())
        }
        err = k.bank.SendCoinsFromAccountToModule(ctx, black, types.ModuleName, sdk.NewCoins(storedGame.GetWagerCoin()))
        if err != nil {
            return sdkerrors.Wrapf(err, types.ErrBlackCannotPay.Error())
        }
    } else if storedGame.MoveCount == 1 {
        // Red plays second
        red, err := storedGame.GetRedAddress()
        if err != nil {
            panic(err.Error())
        }
        err = k.bank.SendCoinsFromAccountToModule(ctx, red, types.ModuleName, sdk.NewCoins(storedGame.GetWagerCoin()))
        if err != nil {
            return sdkerrors.Wrapf(err, types.ErrRedCannotPay.Error())
        }
    }
    return nil
}

// Game must have a valid winner.
func (k *Keeper) MustPayWinnings(ctx sdk.Context, storedGame *types.StoredGame) {
    // Pay the winnings to the winner
    winnerAddress, found, err := storedGame.GetWinnerAddress()
    if err != nil {
        panic(err.Error())
    }
    if !found {
        panic(fmt.Sprintf(types.ErrCannotFindWinnerByColor.Error(), storedGame.Winner))
    }
    winnings := storedGame.GetWagerCoin()
    if storedGame.MoveCount == 0 {
        panic(types.ErrNothingToPay.Error())
    } else if 1 < storedGame.MoveCount {
        winnings = winnings.Add(winnings)
    }
    err = k.bank.SendCoinsFromModuleToAccount(ctx, types.ModuleName, winnerAddress, sdk.NewCoins(winnings))
    if err != nil {
        panic(types.ErrCannotPayWinnings.Error())
    }
}

// Game must be in a state where it can be refunded.
func (k *Keeper) MustRefundWager(ctx sdk.Context, storedGame *types.StoredGame) {
    // Refund wager to black player if red rejects after black played
    if storedGame.MoveCount == 1 {
        black, err := storedGame.GetBlackAddress()
        if err != nil {
            panic(err.Error())
        }
        err = k.bank.SendCoinsFromModuleToAccount(ctx, types.ModuleName, black, sdk.NewCoins(storedGame.GetWagerCoin()))
        if err != nil {
            panic(fmt.Sprintf(types.ErrCannotRefundWager.Error(), rules.BLACK_PLAYER.Color))
        }
    } else if storedGame.MoveCount == 0 {
        // Do nothing
    } else {
        // TODO Implement a draw mechanism.
        panic(fmt.Sprintf(types.ErrNotInRefundState.Error(), storedGame.MoveCount))
    }
}
```
Create `x/checkers/keeper/end_block_server_game.go`
```go
func (k Keeper) ForfeitExpiredGames(goCtx context.Context) {
    ctx := sdk.UnwrapSDKContext(goCtx)

	// Get FIFO information
	nextGame, found := k.GetNextGame(ctx)
	if !found {
	    return
	}
	
    opponents := map[string]string{
        rules.PieceStrings[rules.BLACK_PLAYER]: rules.PieceStrings[rules.RED_PLAYER],
        rules.PieceStrings[rules.RED_PLAYER]:   rules.PieceStrings[rules.BLACK_PLAYER],
    }
    
    storedGameId := nextGame.FifoHead
    var storedGame types.StoredGame
    for {
        // Finished moving along
        if strings.Compare(storedGameId, types.NoFifoIdKey) == 0 {
            break
        }
        storedGame, found = k.GetStoredGame(ctx, storedGameId)
        if !found {
            panic("Fifo head game not found " + nextGame.FifoHead)
        }
        deadline, err := storedGame.GetDeadlineAsTime()
        if err != nil {
            panic(err)
        }
        if deadline.Before(ctx.BlockTime()) {
            // Game is past deadline
            k.RemoveFromFifo(ctx, &storedGame, &nextGame)
            if storedGame.MoveCount <= 1 {
                // No point in keeping a game that was never really played
                k.RemoveStoredGame(ctx, storedGameId)
                if storedGame.MoveCount == 1 {
                    k.MustRefundWager(ctx, &storedGame)
                }
            } else {
                storedGame.Winner, found = opponents[storedGame.Turn]
                if !found {
                    panic(fmt.Sprintf(types.ErrCannotFindWinnerByColor.Error(), storedGame.Turn))
                }
                k.MustPayWinnings(ctx, &storedGame)
                k.SetStoredGame(ctx, storedGame)
            }
    
            // Move along FIFO
            storedGameId = nextGame.FifoHead
        } else {
            // All other games come after anyway
            break
        }
    }
    
    k.SetNextGame(ctx, nextGame)
}
```
Update `x/checkers/keeper/msg_server_create_game.go`
```go
func (k msgServer) CreateGame(goCtx context.Context, msg *types.MsgCreateGame) (*types.MsgCreateGameResponse, error) {
    ctx := sdk.UnwrapSDKContext(goCtx)
    
    nextGame, found := k.Keeper.GetNextGame(ctx)
    if !found {
        panic("NextGame not found")
    }
    newIndex := strconv.FormatUint(nextGame.IdValue, 10)
    newGame := rules.New()
    storedGame := types.StoredGame{
        Index:     newIndex,
        Game:      newGame.String(),
        Turn:      rules.PieceStrings[newGame.Turn],
        Red:       msg.Red,
        Black:     msg.Black,
        MoveCount: 0,
        BeforeId:  types.NoFifoIdKey,
        AfterId:   types.NoFifoIdKey,
        Deadline:  types.FormatDeadline(types.GetNextDeadline(ctx)),
        Winner:    rules.PieceStrings[rules.NO_PLAYER],
        Wager:     msg.Wager,
    }
    err := storedGame.Validate()
    if err != nil {
        return nil, err
    }
    k.Keeper.SendToFifoTail(ctx, &storedGame, &nextGame)
    k.Keeper.SetStoredGame(ctx, storedGame)
        
    nextGame.IdValue++
    k.Keeper.SetNextGame(ctx, nextGame)
    
    return &types.MsgCreateGameResponse{
        IdValue: newIndex,
    }, nil
}
```
Update `x/checkers/keeper/msg_server_play_move.go`
```go
func (k msgServer) PlayMove(goCtx context.Context, msg *types.MsgPlayMove) (*types.MsgPlayMoveResponse, error) {
    ctx := sdk.UnwrapSDKContext(goCtx)
    
    storedGame, found := k.Keeper.GetStoredGame(ctx, msg.IdValue)
    if !found {
        return nil, sdkerrors.Wrapf(types.ErrGameNotFound, "game not found %s", msg.IdValue)
    }

    // Is the game already won? Can happen when it is forfeited.
    if storedGame.Winner != rules.PieceStrings[rules.NO_PLAYER] {
        return nil, types.ErrGameFinished
    }
    
    // Is it an expected player?
    isRed := strings.Compare(storedGame.Red, msg.Creator) == 0
    isBlack := strings.Compare(storedGame.Black, msg.Creator) == 0
    var player rules.Player
    if !isRed && !isBlack {
        return nil, types.ErrCreatorNotPlayer
    } else if isRed && isBlack {
        player = rules.StringPieces[storedGame.Turn].Player
    } else if isRed {
        player = rules.RED_PLAYER
    } else {
        player = rules.BLACK_PLAYER
    }
    
    // Is it the player's turn?
    game, err := storedGame.ParseGame()
    if err != nil {
        panic(err.Error())
    }
    if !game.TurnIs(player) {
        return nil, types.ErrNotPlayerTurn
    }

    // Make the player pay the wager at the beginning
    err = k.Keeper.CollectWager(ctx, &storedGame)
    if err != nil {
        return nil, err
    }
    
    // Do it
    captured, moveErr := game.Move(
        rules.Pos{
            X: int(msg.FromX),
            Y: int(msg.FromY),
        },
        rules.Pos{
            X: int(msg.ToX),
            Y: int(msg.ToY),
        },
    )
    if moveErr != nil {
        return nil, sdkerrors.Wrapf(types.ErrWrongMove, moveErr.Error())
    }
    storedGame.MoveCount++
	storedGame.Deadline = types.FormatDeadline(types.GetNextDeadline(ctx))
    storedGame.Winner = rules.PieceStrings[game.Winner()]

    // Send to the back of the FIFO
    nextGame, found := k.Keeper.GetNextGame(ctx)
    if !found {
        panic("NextGame not found")
    }
    if storedGame.Winner == rules.PieceStrings[rules.NO_PLAYER] {
        k.Keeper.SendToFifoTail(ctx, &storedGame, &nextGame)
    } else {
        k.Keeper.RemoveFromFifo(ctx, &storedGame, &nextGame)

        // Pay the winnings to the winner
        k.Keeper.MustPayWinnings(ctx, &storedGame)
    }
    
    // Save for the next play move
    storedGame.Game = game.String()
    storedGame.Turn = rules.PieceStrings[game.Turn]
    k.Keeper.SetStoredGame(ctx, storedGame)
    k.Keeper.SetNextGame(ctx, nextGame)
    
    // What to inform
    return &types.MsgPlayMoveResponse{
        IdValue:   msg.IdValue,
        CapturedX: int32(captured.X),
        CapturedY: int32(captured.Y),
        Winner:    rules.PieceStrings[game.Winner()],
    }, nil
}
```
Update `x/checkers/keeper/msg_server_reject_game.go`
```go
func (k msgServer) RejectGame(goCtx context.Context, msg *types.MsgRejectGame) (*types.MsgRejectGameResponse, error) {
    ctx := sdk.UnwrapSDKContext(goCtx)
    
    storedGame, found := k.Keeper.GetStoredGame(ctx, msg.IdValue)
    if !found {
        return nil, sdkerrors.Wrapf(types.ErrGameNotFound, "game not found %s", msg.IdValue)
    }
    // Is the game already won? Here, likely because it is forfeited.
    if storedGame.Winner != rules.PieceStrings[rules.NO_PLAYER] {
        return nil, types.ErrGameFinished
    }
        
    // Is it an expected player? And did the player already play?
    if strings.Compare(storedGame.Red, msg.Creator) == 0 {
        if 1 < storedGame.MoveCount {
            return nil, types.ErrRedAlreadyPlayed
        }
    } else if strings.Compare(storedGame.Black, msg.Creator) == 0 {
        if 0 < storedGame.MoveCount {
            return nil, types.ErrBlackAlreadyPlayed
        }
    } else {
        return nil, types.ErrCreatorNotPlayer
    }

    // Refund wager to black player if red rejects after black played
    k.Keeper.MustRefundWager(ctx, &storedGame)

    // Remove from the FIFO
    nextGame, found := k.Keeper.GetNextGame(ctx)
    if !found {
        panic("NextGame not found")
    }
    k.Keeper.RemoveFromFifo(ctx, &storedGame, &nextGame)
    
    // Remove the game completely as it is not interesting to keep it.
    k.Keeper.RemoveStoredGame(ctx, msg.IdValue)
    k.Keeper.SetNextGame(ctx, nextGame)
    
    return &types.MsgRejectGameResponse{}, nil
}
```
Update the default genesis state in `x/checkers/types/genesis.go` to
```go
func DefaultGenesis() *GenesisState {
    return &GenesisState{
        NextGame: &NextGame{
            IdValue: DefaultIndex,
            FifoHead: NoFifoIdKey,
            FifoTail: NoFifoIdKey,
        },
        ...
    }
}
```
Update the `EndBlock` function in `x/checkers/module.go`
```go
func (am AppModule) EndBlock(ctx sdk.Context, _ abci.RequestEndBlock) []abci.ValidatorUpdate {
    am.keeper.ForfeitExpiredGames(sdk.WrapSDKContext(ctx))
    ...
}
```
*Make sure that `app.mm.SetOrderEndBlockers` in `app/app.go` also contains `checkersmoduletypes.ModuleName` at the end*

Update `app.go`
```go
app.CheckersKeeper = *checkersmodulekeeper.NewKeeper(
    app.BankKeeper,
    ...
)

maccPerms = map[string][]string{
    ...
    checkersmoduletypes.ModuleName: nil,
}
```
