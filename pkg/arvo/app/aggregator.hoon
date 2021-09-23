::  aggregator: Azimuth L2 roll aggregator
::
::    general flow is as described below, to ensure transactions actually go
::    through once we start sending it out, in the dumbest reasonable way.
::
::    periodic timer fires:
::    if there are no pending l2 txs, do nothing.
::    else kick off tx submission flow:
::    "freeze" pending txs, store alongside nonce, then increment nonce,
::    kick off thread for sending the corresponding l1 tx:
::      if nonce doesn't match on-chain expected nonce, bail.
::      if we can't afford the tx fee, bail.
::      construct, sign, submit the l1 tx.
::    if thread bailed, retry in five minutes.
::    if thread succeeded, retry in five minutes with higher gas price.
::    when retrying, only do so if l2 txs remain in the "frozen" txs group.
::    on %tx diff from naive, remove the matching tx from the frozen group.
::
::TODO  questions:
::  - it's a bit weird how we just assume the raw and tx in raw-tx to match...
::
/-  *dice
/+  azimuth,
    naive,
    dice,
    lib=naive-transactions,
    default-agent,
    ethereum,
    dbug,
    verb
::
|%
+$  state-0
  $:  %0
      ::  pending: the next l2 txs to be sent
      ::  sending: the l2 txs currently sending/awaiting l2 confirmation
      ::  finding: raw-tx-hash reverse lookup for sending map
      ::  history: status of l2 txs by ethereum address
      ::  transfers: index that keeps track of transfer-proxy changes
      ::  next-nonce: next l1 nonce to use
      ::  next-batch: when then next l2 batch will be sent
      ::  pre: predicted l2 state
      ::  own: ownership of azimuth points
      ::  derive-p: flag (derive predicted state)
      ::  derive-o: flag (derive ownership state)
      ::
      pending=(list pend-tx)
    ::
      $=  sending
      %+  map  l1-tx-pointer
      [next-gas-price=@ud txs=(list raw-tx:naive)]
    ::
      finding=(map keccak ?(%confirmed %failed l1-tx-pointer))
      history=(jug address:ethereum roller-tx)
      transfers=(map ship address:ethereum)
      next-nonce=(unit @ud)
      next-batch=time
      pre=^state:naive
      own=owners
      derive-p=?
      derive-o=?
    ::
      ::  pk: private key to send the roll
      ::  frequency: time to wait between sending batches (TODO fancier)
      ::  endpoint: ethereum rpc endpoint to use
      ::  contract: ethereum contract address
      ::  chain-id: mainnet, ropsten, local (https://chainid.network/)
      ::
      pk=@
      frequency=@dr
      endpoint=(unit @t)
      contract=@ux
      chain-id=@
  ==
::
+$  init  [nas=^state:naive own=owners]
::
+$  config
  $%  [%frequency frequency=@dr]
      [%setkey pk=@]
      [%endpoint endpoint=@t]
      [%network net=?(%mainnet %ropsten %local)]
  ==
::
+$  action
  $%  ::  we need to include the address in submit so pending txs show up
      ::  in the tx history, but because users can send the wrong
      ::  address, in +apply-tx:predicted state, we just replace
      ::  the provided address, with the one used when the message was signed;
      ::
      ::  we need to do it there to know the correct nonce that the signed
      ::  message should have included.
      ::
      [%submit force=? =address:naive sig=@ tx=part-tx]
      [%cancel sig=@ keccak=@ =l2-tx =ship]
      [%commit ~]  ::TODO  maybe pk=(unit @) later
      [%config config]
  ==
::
+$  card  card:agent:gall
::
::  TODO: add to config
::
++  resend-time  ~m5
::
++  lverb  &
--
::
=|  state-0
=*  state  -
::
%-  agent:dbug
%+  verb  |
^-  agent:gall
::
=<
  |_  =bowl:gall
  +*  this  .
      do    ~(. +> bowl)
      def   ~(. (default-agent this %|) bowl)
  ::
  ++  on-init
    ^-  (quip card _this)
    =.  frequency  ~h1
    =.  contract  naive:local-contracts:azimuth
    =.  chain-id  chain-id:local-contracts:azimuth
    =^  card  next-batch  set-timer
    :_  this
    :~  card
        [%pass /azimuth-events %agent [our.bowl %azimuth] %watch /event]
    ==
  ::
  ++  on-save  !>(state)
  ++  on-load
    |=  old=vase
    ^-  (quip card _this)
    [~ this(state !<(state-0 old))]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =^  cards  state
      ?+    mark  (on-poke:def mark vase)
          %aggregator-action
        =+  !<(poke=action vase)
        (on-action:do poke)
      ==
    [cards this]
  ::  +on-peek: scry paths
  ::
  ::    /x/pending                     ->  %noun  (list pend-tx)
  ::    /x/pending/[~ship]             ->  %noun  (list pend-tx)
  ::    /x/pending/[0xadd.ress]        ->  %noun  (list pend-tx)
  ::    /x/tx/[0xke.ccak]/status       ->  %noun  tx-status
  ::    /x/history/[0xadd.ress]        ->  %noun  (list roller-tx)
  ::    /x/nonce/[~ship]/[proxy]       ->  %noun  (unit @)
  ::    /x/spawned/[~ship]             ->  %noun  (list [ship address])
  ::    /x/next-batch                  ->  %atom  time
  ::    /x/point/[~ship]               ->  %noun  point:naive
  ::    /x/points/[0xadd.ress]         ->  %noun  (list [ship point:naive])
  ::    /x/config                      ->  %noun  config
  ::    /x/chain-id                    ->  %atom  @
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    |^
    ?+  path  ~
      [%x %pending ~]       ``noun+!>(pending)
      [%x %pending @ ~]     (pending-by i.t.t.path)
      [%x %tx @ %status ~]  (status i.t.t.path)
      [%x %history @ ~]     (history i.t.t.path)
      [%x %nonce @ @ ~]     (nonce i.t.t.path i.t.t.t.path)
      [%x %spawned @ ~]     (spawned i.t.t.path)
      [%x %next-batch ~]    ``atom+!>(next-batch)
      [%x %point @ ~]       (point i.t.t.path)
      [%x %points @ ~]      (points i.t.t.path)
      [%x %config ~]        config
      [%x %chain-id ~]      ``atom+!>(chain-id)
    ==
    ::
    ++  pending-by
      |=  wat=@t
      ?~  who=(slaw %p wat)
        ::  by-address
        ::
        ?~  wer=(slaw %ux wat)
          [~ ~]
        =;  pending=(list pend-tx)
          ``noun+!>(pending)
        %+  skim  pending
        |=  pend-tx
        =(u.wer (need (get-l1-address tx.raw-tx pre)))
      ::  by-ship
      ::
      =;  pending=(list pend-tx)
        ``noun+!>(pending)
      %+  skim  pending
      |=  pend-tx
      =(u.who ship.from.tx.raw-tx)
    ::
    ++  status
      |=  wat=@t
      ?~  keccak=(slaw %ux wat)
        [~ ~]
      :+  ~  ~
      :-  %noun
      !>  ^-  tx-status
      ?^  status=(~(get by finding) u.keccak)
        ?@  u.status  [u.status ~]
        [%sending status]
      ::TODO  potentially slow!
      =;  known=?
        [?:(known %pending %unknown) ~]
      %+  lien  pending
      |=  pend-tx
      =(u.keccak (hash-tx:lib raw.raw-tx))
    ::
    ++  history
      |=  wat=@t
      :+  ~  ~
      :-  %noun
      !>  ^-  (list roller-tx)
      ?~  addr=(slaw %ux wat)  ~
      %~  tap  in
      (~(get ju ^history) u.addr)
    ::
    ++  nonce
      |=  [who=@t proxy=@t]
      ?~  who=(slaw %p who)
        [~ ~]
      ?.  ?=(proxy:naive proxy)
        [~ ~]
      :+  ~  ~
      :-  %noun
      !>  ^-  (unit @)
      ?~  point=(get:orm:naive points.pre u.who)
        ~
      =<  `nonce
      (proxy-from-point:naive proxy u.point)
    ::
    ++  spawned
      |=  wat=@t
      :+  ~  ~
      :-  %noun
      !>  ^-  (list [=^ship =address:ethereum])
      ?~  star=(slaw %p wat)  ~
      =/  range
        %+  lot:orm:naive  points.pre
        ::  range exclusive [star next-star-first-planet-]
        ::  TODO: make range inclusive ([first-planet last-planet])?
        ::
        [`u.star `(cat 3 +(u.star) 0x1)]
      %+  turn  (tap:orm:naive range)
      |=  [=ship =point:naive]
      ^-  [=^ship =address:ethereum]
      :-  ship
      address:(proxy-from-point:naive %own point)
    ::
    ++  point
      |=  wat=@t
      ?~  ship=(rush wat ;~(pfix sig fed:ag))
        ``noun+!>(*(unit point:naive))
      ``noun+!>((get:orm:naive points.pre u.ship))
    ::
    ++  points
      |=  wat=@t
      :+  ~  ~
      :-  %noun
      !>  ^-  (list ship)
      ?~  addr=(slaw %ux wat)
        ~
      %~  tap  in
      (~(get ju own) u.addr)
    ::
    ++  config
      :+  ~  ~
      :-  %noun
      !>  ^-  roller-config
      :*  next-batch
          frequency
          resend-time
          contract
          chain-id
      ==
    --
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    ?+    wire  (on-arvo:def wire sign-arvo)
        [%timer ~]
      ?+  +<.sign-arvo  (on-arvo:def wire sign-arvo)
        %wake  =^(cards state on-timer:do [cards this])
      ==
    ::
        [%predict ~]
      ?+    +<.sign-arvo  (on-arvo:def wire sign-arvo)
          %wake
        =.  state  (predicted-state canonical-state):do
        `this(derive-p &)
      ==
    ::
        [%owners ~]
      ?+    +<.sign-arvo  (on-arvo:def wire sign-arvo)
          %wake
        =.  own.state  canonical-owners:do
        `this(derive-o &)
      ==
    ::
        [%resend @ @ ~]
      =/  [address=@ux nonce=@ud]
        [(slav %ux i.t.wire) (rash i.t.t.wire dem)]
      ?+  +<.sign-arvo  (on-arvo:def wire sign-arvo)
        %wake  [(send-roll:do address nonce) this]
      ==
    ==
  ::
  ++  on-fail
    |=  [=term =tang]
    ::TODO  if crashed during timer, set new timer? how to detect?
    (on-fail:def term tang)
  ::
  ++  on-watch  on-watch:def
  ++  on-leave  on-leave:def
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    |^
    ?+  wire  (on-agent:def wire sign)
      [%send @ @ *]        (send-batch i.t.wire i.t.t.wire sign)
      [%azimuth-events ~]  (azimuth-event sign)
      [%nonce ~]           (nonce sign)
    ==
    ::
    ++  send-batch
      |=  [address=@t nonce=@t =sign:agent:gall]
      ^-  (quip card _this)
      =/  [address=@ux nonce=@ud]
        [(slav %ux address) (rash nonce dem)]
      ?-  -.sign
          %poke-ack
        ?~  p.sign
          %-  (slog leaf+"Send batch thread started successfully" ~)
          [~ this]
        %-  (slog leaf+"{(trip dap.bowl)} couldn't start thread" u.p.sign)
        :_  this
        [(leave:spider:do wire)]~
      ::
          %watch-ack
        ?~  p.sign
          [~ this]
        =/  =tank  leaf+"{(trip dap.bowl)} couldn't start listen to thread"
        %-  (slog tank u.p.sign)
        [~ this]
      ::
          %kick
        [~ this]
      ::
          %fact
        ?+  p.cage.sign  (on-agent:def wire sign)
            %thread-fail
          =+  !<([=term =tang] q.cage.sign)
          %-  (slog leaf+"{(trip dap.bowl)} failed" leaf+<term> tang)
          =^  cards  state
            (on-batch-result:do address nonce %.n^'thread failed')
          [cards this]
        ::
            %thread-done
          =+   !<(result=(each @ud @t) q.cage.sign)
          =^  cards  state
            (on-batch-result:do address nonce result)
          [cards this]
        ==
      ==
    ::
    ++  azimuth-event
      |=  =sign:agent:gall
      ^-  (quip card _this)
      ?+  -.sign  [~ this]
          %watch-ack
        ?~  p.sign  [~ this]
        =/  =tank  leaf+"{(trip dap.bowl)} couldn't start listen to %azimuth"
        %-  (slog tank u.p.sign)
        [~ this]
      ::
          %fact
        ?+  p.cage.sign  (on-agent:def wire sign)
            %naive-diffs
          =+   !<(=diff:naive q.cage.sign)
          =^  cards  state
            (on-naive-diff:do diff)
          [cards this]
        ::
            %naive-state
          ~&  >  %received-azimuth-state
          ::  cache naive and ownership state
          ::
          =^  nas  own.state  !<(init q.cage.sign)
          =.  state  (predicted-state:do nas)
          `this
        ==
      ==
    ::
    ++  nonce
      |=  =sign:agent:gall
      ^-  (quip card _this)
      ?-  -.sign
          %poke-ack
        ?~  p.sign
          %-  (slog leaf+"Nonce thread started successfully" ~)
          [~ this]
        %-  (slog leaf+"{(trip dap.bowl)} couldn't start thread" u.p.sign)
        :_  this
        [(leave:spider:do wire)]~
      ::
          %watch-ack
        ?~  p.sign
          [~ this]
        =/  =tank  leaf+"{(trip dap.bowl)} couldn't start listen to thread"
        %-  (slog tank u.p.sign)
        [~ this]
      ::
          %kick
        [~ this]
      ::
          %fact
        ?+  p.cage.sign  (on-agent:def wire sign)
            %thread-fail
          =+  !<([=term =tang] q.cage.sign)
          %-  (slog leaf+"{(trip dap.bowl)} failed" leaf+<term> tang)
          [~ this]
        ::
            %thread-done
          =+   !<(nonce=@ud q.cage.sign)
          [~ this(next-nonce `nonce)]
        ==
      ==
    --
  --
::
|_  =bowl:gall
::TODO  /lib/sys.hoon?
++  sys
  |%
  ++  b
    |%
    ++  wait
      |=  [=wire =time]
      ^-  card
      [%pass wire %arvo %b %wait time]
    --
  --
::TODO  /lib/spider.hoon?
++  spider
  |%
  ++  start-thread
    |=  [=wire thread=term arg=vase]
    ^-  (list card)
    =/  tid=@ta  (rap 3 thread '--' (scot %uv eny.bowl) ~)
    =/  args     [~ `tid thread arg]
    :~  [%pass wire %agent [our.bowl %spider] %watch /thread-result/[tid]]
        [%pass wire %agent [our.bowl %spider] %poke %spider-start !>(args)]
    ==
  ::
  ++  leave
    |=  =path
    ^-  card
    [%pass path %agent [our.bowl %spider] %leave ~]
  --
::
++  part-tx-to-full
  |=  =part-tx
  ^-  [octs tx:naive]
  ?-    -.part-tx
      %raw
    ?~  batch=(parse-raw-tx:naive 0 q.raw.part-tx)
      ~&  %parse-failed
      ::  TODO: maybe return a unit if parsing fails?
      ::
      !!
    [raw tx]:-.u.batch
  ::
    %don  [(gen-tx-octs:lib +.part-tx) +.part-tx]
    %ful  +.part-tx
  ==
::  +canonical-state: current l2 state from /app/azimuth
::
++  canonical-state
  .^  ^state:naive
    %gx
    (scot %p our.bowl)
    %azimuth
    (scot %da now.bowl)
    /nas/noun
  ==
::  +canonical-owners: current azimuth point ownership
::
++  canonical-owners
  .^  owners
    %gx
    (scot %p our.bowl)
    %azimuth
    (scot %da now.bowl)
    /own/noun
  ==
::  +predicted-state
::
::    derives predicted state from applying pending/sending txs to
::    the canonical state, discarding invalid txs in the process.
::
++  predicted-state
  |=  nas=^state:naive
  ^+  state
  =.  pre.state  nas
  |^
  =^  nes  state  apply-sending
  =^  nep  state  apply-pending
  state(sending nes, pending nep)
  ::
  ++  apply-pending
    (apply-txs pending %pending)
  ::
  ++  apply-sending
    =|  valid=_sending
    =+  sending=~(tap by sending)
    |-  ^+  [valid state]
    ?~  sending  [valid state]
    ::
    =*  key  p.i.sending
    =*  val  q.i.sending
    =^  new-valid  state
      %+  apply-txs
        (turn txs.val |=(=raw-tx:naive [| 0x0 raw-tx]))
      %sending
    =.  valid
      %+  ~(put by valid)  key
      val(txs (turn new-valid (cork tail tail)))
    $(sending t.sending)
  ::
  ++  apply-txs
    |=  [txs=(list pend-tx) type=?(%pending %sending)]
    =/  valid=_txs  ~
    :: =|  local=(set keccak)
    |-  ^+  [valid state]
    ?~  txs  [valid state]
    ::
    =*  tx      i.txs
    =*  raw-tx  raw-tx.i.txs
    =*  ship    ship.from.tx.raw-tx.i.txs
    =/  hash=@ux  (hash-raw-tx:lib raw-tx)
    ::  TODO: add tests to validate if this is necessary
    ::
    :: ?:  (~(has in local) hash)
    ::   ::  if tx was already seen here, skip
    ::   ::
    ::   $(txs t.txs)
    =/  sign-address=(unit @ux)
      (extract-address:lib raw-tx pre.state chain-id)
    =^  gud=?  state
      (try-apply pre.state force.tx raw-tx)
    ::  TODO: only replace address if !=(address.tx sign-address)?
    ::
    =?  tx  &(gud ?=(^ sign-address))
      tx(address u.sign-address)
    =?  valid  gud  (snoc valid tx)
    =?  finding.state  !gud
      (~(put by finding.state) [hash %failed])
    =?  history.state  !gud
      =/  =roller-tx
        [ship type hash (l2-tx +<.tx.raw-tx)]
      %.  [address.tx roller-tx(status %failed)]
      ~(put ju (~(del ju history.state) address.tx roller-tx))
    :: $(txs t.txs, local (~(put in local) hash))
    $(txs t.txs)
  ::
  ++  try-apply
    |=  [nas=^state:naive force=? =raw-tx:naive]
    ^-  [? _state]
    =/  [success=? predicted=_nas owners=_own]
      (apply-raw-tx:dice force raw-tx nas own chain-id)
    :-  success
    state(pre predicted, own owners)
  --
::
++  get-l1-address
  |=  [=tx:naive nas=^state:naive]
  ^-  (unit address:ethereum)
  ?~  point=(get:orm:naive points.nas ship.from.tx)  ~
  =<  `address
  (proxy-from-point:naive proxy.from.tx u.point)
::
++  on-action
  |=  =action
  ^-  (quip card _state)
  ?-  -.action
    %commit  on-timer
    %config  (on-config +.action)
    %cancel  (cancel-tx +.action)
  ::
      %submit
    %-  take-tx
    :^    force.action
        address.action
      sig.action
    (part-tx-to-full tx.action)
  ==
::
++  on-config
  |=  =config
  ^-  (quip card _state)
  ?-  -.config
    %frequency  [~ state(frequency frequency.config)]
    %endpoint   [~ state(endpoint `endpoint.config)]
  ::
      %network
    :-  ~
    =/  [contract=@ux chain-id=@]
      =<  [naive chain-id]
      =,  azimuth
      ?-  net.config
        %mainnet  mainnet-contracts
        %ropsten  ropsten-contracts
        %local    local-contracts
      ==
    state(contract contract, chain-id chain-id)
  ::
      %setkey
    ?~  pk=(de:base16:mimes:html pk.config)
      `state
    [(get-nonce q.u.pk) state(pk q.u.pk)]
  ==
::  TODO: move address to state?
::
++  get-address
  ^-  address:ethereum
  (address-from-prv:key:ethereum pk)
::  +cancel-tx: cancel a pending transaction
::
++  cancel-tx
  |=  [sig=@ =keccak =l2-tx =ship]
  ^-  (quip card _state)
  ?^  status=(~(get by finding) keccak)
    ~?  lverb  [dap.bowl %tx-not-pending status+u.status]
    [~ state]
  ::  "cancel: 0x1234abcd"
  ::
  =/  message=octs
    %:  cad:naive  3
      8^'cancel: '
    ::
      =;  hash=@t
        (met 3 hash)^hash
      (crip "0x{((x-co:co 20) keccak)}")
    ::
      ~
    ==
  ?~  addr=(verify-sig:lib sig message)
    ~?  lverb  [dap.bowl %cancel-sig-fail]
    [~ state]
  ::  TODO: mark as failed instead? add a %cancelled to tx-status?
  ::
  =.  history
    %+  ~(del ju history)  u.addr
    [ship %pending keccak l2-tx]
  =.  pending
    %+  skip  pending
    |=  pend-tx
    =(keccak (hash-raw-tx:lib raw-tx))
  [~ state]
::  +take-tx: accept submitted l2 tx into the :pending list
::
++  take-tx
  |=  pend-tx
  ^-  (quip card _state)
  =/  hash=@ux  (hash-raw-tx:lib raw-tx)
  ::  TODO: what if this hash/tx is already in the history?
  ::    e.g. if previously failed, but now it will go through
  ::    a) check in :finding that hash doesn't exist and if so, skip ?
  ::    b) extract the status from :finding, use it to delete
  ::      the entry in :history, and then insert it as %pending ?
  ::
  :: =/  not-sent=?  !(~(has by finding) hash)
  :: =?  pending  not-sent
  =.  pending  (snoc pending [force address raw-tx])
  :: =?  history  not-sent
  =.  history
    %+  ~(put ju history)  address
    [ship.from.tx.raw-tx %pending hash (l2-tx +<.tx.raw-tx)]
  =?  transfers  =(%transfer-point (l2-tx +<.tx.raw-tx))
    (~(put by transfers) ship.from.tx.raw-tx address)
  :: ?.  not-sent  ~&  "skip"  [~ state]
  ::  toggle flush flag
  ::
  :_  state(derive-p ?:(derive-p | derive-p))
  ?.  derive-p  ~
  ::  derive predicted state in 5m.
  ::
  [(wait:b:sys /predict (add ~m5 now.bowl))]~
::  +set-timer: %wait until next whole :frequency
::
++  set-timer
  ^-  [=card =time]
  =+  time=(mul +((div now.bowl frequency)) frequency)
  [(wait:b:sys /timer time) time]
::  +on-timer: every :frequency, freeze :pending txs roll and start sending it
::
++  on-timer
  ^-  (quip card _state)
  =.  state  (predicted-state canonical-state)
  =^  cards  state
    ?:  =(~ pending)  [~ state]
    ?~  next-nonce
      ~&([dap.bowl %no-nonce] [~ state])
    =/  nonce=@ud   u.next-nonce
    =:  pending     ~
        derive-p    &
        next-nonce  `+(u.next-nonce)
      ::
          sending
        %+  ~(put by sending)
          [get-address nonce]
        [0 (turn pending (cork tail tail))]
      ::
          finding
        %-  ~(gas by finding)
        %+  turn  pending
        |=  pend-tx
        (hash-raw-tx:lib raw-tx)^[address nonce]
      ::
          history
        %+  roll  pending
        |=  [pend-tx hist=_history]
        =/  tx=roller-tx
          :^      ship.from.tx.raw-tx
              %pending
            (hash-raw-tx:lib raw-tx)
          (l2-tx +<.tx.raw-tx)
        %+  ~(put ju (~(del ju hist) address tx))
          address
        tx(status %sending)
      ==
    [(send-roll get-address nonce) state]
  =^  card  next-batch  set-timer
  [[card cards] state]
::  +get-nonce: retrieves the latest nonce
::
++  get-nonce
  |=  pk=@
  ^-  (list card)
  ?~  endpoint  ~&([dap.bowl %no-endpoint] ~)
  (start-thread:spider /nonce [%aggregator-nonce !>([u.endpoint pk])])
::
::  +send-roll: start thread to submit roll from :sending to l1
::
++  send-roll
  |=  [=address:ethereum nonce=@ud]
  ^-  (list card)
  ::  if this nonce isn't in the sending queue anymore, it's done
  ::
  ?.  (~(has by sending) [address nonce])
    ~?  lverb  [dap.bowl %done-sending [address nonce]]
    ~
  ::  start the thread, passing in the l2 txs to use
  ::
  ?~  endpoint  ~&([dap.bowl %no-endpoint] ~)
  ::TODO  should go ahead and set resend timer in case thread hangs, or nah?
  %+  start-thread:spider
    /send/(scot %ux address)/(scot %ud nonce)
  :-  %aggregator-send
  !>  ^-  rpc-send-roll
  :*  u.endpoint
      contract
      chain-id
      pk
      nonce
      (~(got by sending) [address nonce])
  ==
::  +on-batch-result: await resend after thread success or failure
::
++  on-batch-result
  |=  [=address:ethereum nonce=@ud result=(each @ud @t)]
  ^-  (quip card _state)
  ::  update gas price for this tx in state
  ::
  =?  sending  ?=(%& -.result)
    %+  ~(jab by sending)  [address nonce]
    (cork tail (lead p.result))
  ::  print error if there was one
  ::
  ~?  ?=(%| -.result)  [dap.bowl %send-error p.result]
  ::  resend the l1 tx in five minutes
  ::
  :_  state
  :_  ~
  %+  wait:b:sys
    /resend/(scot %ux address)/(scot %ud nonce)
  (add resend-time now.bowl)
::  +on-naive-diff: process l2 tx confirmations
::
++  on-naive-diff
  |=  =diff:naive
  ^-  (quip card _state)
  ?:  ?=(%point -.diff)
    :_  state(derive-o ?:(derive-o | derive-o))
    ?.  derive-o  ~
    ::  calculate ownership in 5m.
    ::
    [(wait:b:sys /owners (add ~m5 now.bowl))]~
  ?.  ?=(%tx -.diff)
    [~ state]
  =/  =keccak  (hash-raw-tx:lib raw-tx.diff)
  ?~  wer=(~(get by finding) keccak)
    [~ state]
  ::  if we had already seen the tx, no-op
  ::
  ?@  u.wer
    ~?  &(?=(%confirmed u.wer) ?=(~ err.diff))
      [dap.bowl %weird-double-confirm from.tx.raw-tx.diff]
    [~ state]
  =*  nonce  nonce.u.wer
  =*  ship   ship.from.tx.raw-tx.diff
  ::  remove the tx from the sending map
  ::
  =.  sending
    ?~  sen=(~(get by sending) [get-address nonce])
      ~&  [dap.bowl %weird-double-remove]
      sending
    ?~  nin=(find [raw-tx.diff]~ txs.u.sen)
      ~&  [dap.bowl %weird-unknown]
      sending
    =.  txs.u.sen  (oust [u.nin 1] txs.u.sen)
    ?~  txs.u.sen
      ~?  lverb  [dap.bowl %done-with-nonce [get-address nonce]]
      (~(del by sending) [get-address nonce])
    (~(put by sending) [get-address nonce] u.sen)
  ::  update the finding map with the new status
  ::
  =.  finding
    %+  ~(put by finding)  keccak
    ?~  err.diff  %confirmed
    ::  if we kept the forced flag around for longer, we could notify of
    ::  unexpected tx failures here. would that be useful? probably not?
    ::  ~?  !forced  [dap.bowl %aggregated-tx-failed-anyway err.diff]
    %failed
  ::
  =.  history
    =/  l2-tx  (l2-tx +<.tx.raw-tx.diff)
    =/  tx=roller-tx  [ship %sending keccak l2-tx]
    ?~  addr=(get-l1-address tx.raw-tx.diff pre)
      history
    =/  =address:ethereum
      ?.  =(%transfer-point l2-tx)
        u.addr
      ::  TODO: delete this ship from the transfer?
      ::
      (~(got by transfers) ship)
    %+  ~(put ju (~(del ju history) address tx))
      address
    %_  tx
      status  ?~(err.diff %confirmed %failed)
    ==
  :_  state(derive-p ?:(derive-p | derive-p))
  ?.  derive-p  ~
  ::  derive predicted state in 5m.
  ::
  [(wait:b:sys /predict (add ~m5 now.bowl))]~
::
--
