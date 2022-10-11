all = require('ramda/src/all'); clone = require('ramda/src/clone'); difference = require('ramda/src/difference'); filter = require('ramda/src/filter'); has = require('ramda/src/has'); identity = require('ramda/src/identity'); init = require('ramda/src/init'); invoker = require('ramda/src/invoker'); isEmpty = require('ramda/src/isEmpty'); isNil = require('ramda/src/isNil'); keys = require('ramda/src/keys'); length = require('ramda/src/length'); map = require('ramda/src/map'); match = require('ramda/src/match'); merge = require('ramda/src/merge'); nth = require('ramda/src/nth'); pickAll = require('ramda/src/pickAll'); prop = require('ramda/src/prop'); #auto_require: srcramda
import {mapO, isAffected, diff, $, isThenable, sf0} from "ramda-extras" #auto_require: esramda-extras
[] = [] #auto_sugar
qq = (f) -> console.log match(/return (.*);/, f.toString())[1], f()
qqq = (...args) -> console.log ...args
_ = (...xs) -> xs


depsWithData = (deps, state) -> $ state, pickAll(keys(deps))

queryStyle = 'color: #da635a; font-weight: 600;'
# selectorStyle = 'color: #b99236; font-weight: 600;'
selectorStyle = 'color: #17a02d; font-weight: 600;'
invokerStyle = 'color: #d185ce; font-weight: 600;'
msStyle = 'color: #000000; font-weight: 500;'
blackStyle = 'color: #000000; font-weight: 600;'

consoleFormat = (xs) ->
	strings = []
	styles = []
	for [str, style] in xs
		strings.push "%c#{str}"
		styles.push style
	return [strings, styles]

toStyle = ({isQ, isS, isI}) ->
	if isQ then queryStyle
	else if isS then selectorStyle
	else if isI then invokerStyle
	else blackStyle

trunc = (s, n = 100) -> if s.length > n then "#{s.substring 0, n-1}..." else s


export class App
	constructor: (config) ->
		defaultConfig =
			initialUI: {}
			queries: {}
			selectors: {}
			runQuery: () -> throw new Error 'app2: must supply runQuery funciton in config'
			runInvoker: () -> throw new Error 'app2: must supply runInvoker funciton in config'
			log: (o) =>
				if o.type == 'run'
					ini = if o.initial then 'INITIAL-' else ''
					[dir, dirS] = $ o.affected, filter((x) -> !!x.dir), map(({k, ...r}) -> [k, toStyle r]), consoleFormat
					[ind, indS] = $ o.affected, filter((x) -> !!x.ind), map(({k, ...r}) -> [k, toStyle r]), consoleFormat
					[dat, datS] = $ o.affected, filter((x) -> !!x.data), map(({k, ...r}) -> [k, toStyle r]), consoleFormat
					sMs = "#{Math.round o.ms}ms (#{Math.round o.ms - o.msSubs}/#{Math.round o.msSubs})"
					console.groupCollapsed "#{ini}RUN #{sMs}: #{dir}%c | #{ind}%c | #{dat}%c | #{o.subCalls.length}",
					...[...dirS, blackStyle, ...indS, blackStyle, ...datS, blackStyle]
					console.log '%c                (directly affected | indirectly affected | affected by data | number of subs called)', 'color: grey; font-style: italic;'
					console.log 'direct changes:  ', o.directChanges
					console.log 'indirect changes:', o.indirectChanges
					console.log 'data changes:    ', o.dataChanges
					console.log 'subs called:     ', o.subCalls
					$ o.affected, map ({k, deps, isQ, isS, query, runRes, ms, ms2}) =>
						sMs = "#{Math.round(ms)}#{ms2 && " (#{Math.round ms2})" || ''}ms"
						if isQ
							console.groupCollapsed "%c#{k} %c#{sMs} %c(#{trunc(sf0(depsWithData deps, @state)).replace(/"([^"]+)":/g, '$1:')})",
							queryStyle,
							msStyle,
							'color: #6D6D6D; font-weight: 400;'
							console.log (config.queryToString || identity)(query)
							console.log runRes
							console.groupEnd()
						else
							console.groupCollapsed "%c#{k} %c#{sMs} %c(#{trunc(sf0(depsWithData deps, @state)).replace(/"([^"]+)":/g, '$1:')})",
							isS && selectorStyle || invokerStyle,
							msStyle,
							'color: #6D6D6D; font-weight: 400;'
							console.log @state[k]
							console.groupEnd()
					console.groupEnd()
				else if o.type == 'run queries'
					console.log "RUN QUERIES #{Math.round o.ms}ms: #{o.ranQueries.join(',')}"
				else throw new Error "NYI #{o.type}"
				config.logCallback?(o, @)
			raf: (f) ->
				rafId = window.requestAnimationFrame f
				return () -> window.cancelAnimationFrame rafId
			perf: () -> performance.now()
			changeCallback: (state) ->
		@config = merge defaultConfig, config
		[resolved, resolvedKeys] = validateConfig @config
		@qsi = resolved
		@allKeys = {...@config.initialUI, ...resolvedKeys}
		@state = @config.initialUI
		# @keyChanges = $ @state, map () -> true
		@totalChanges = @state
		# @hasDataChanges = false
		@dataChanges = {}
		@subs = []
		@runCount = 0

		@queryRes = {}
		@selectorRes = {}

		# @config.raf @run
		# @config.raf @rerunQueries

	start: -> @run true

	setUI: (delta) ->
		# @state = change.meta delta, @state, {}, @totalChanges
		# for k, v of delta
			# @_set k, v
		@_merge delta

	restart: (newState) =>
		@stopCurrentRun()

		# figure out the total delta needed for the reset
		totalDelta = {...newState}
		for k, v of @state
			if !totalDelta[k] then totalDelta[k] = undefined

		@setUI totalDelta
		@queryRes = {}
		@selectorRes = {}

		@run true

	get: (deps) -> $ @state, pickAll keys(deps)

	sub: (deps, cb) ->
		sub = {deps, cb}
		# ensureDeps deps, @, (missing) ->
		# 	new Error "app2: sub with invalid keys: #{missing}. Spelling mistake or forgot declare in initialUI?"
		@subs.push sub
		return () => @subs.splice @subs.indexOf(sub), 1

	# _change: (k, v) => # private helper so we don't have to type this everywhere
	# 	ms0 = performance.now()
	# 	@state = change.meta {[k]: v}, @state, {}, @totalChanges
	# 	# console.log 'change meta', performance.now() - ms0
	# 	ms1 = performance.now()
	# 	test1 = change {[k]: v}, @state
	# 	# console.log 'change', performance.now() - ms1
	# 	@config.changeCallback? @state

	_set: (k, v) => @_merge {[k]: v}

	_merge: (delta) => # private helper so we don't have to type this everywhere
		ms0 = performance.now()
		# @state[k] = v
		@state = {...@state, ...delta}
		# @keyChanges = {...@keyChanges, ...map((->true), delta)}
		@totalChanges = {...@totalChanges, ...delta}
		# console.log 'change meta', performance.now() - ms0
		ms1 = performance.now()
		# console.log 'change', performance.now() - ms1
		@config.changeCallback? @state

	runQuery: ({k, f, deps, rerun, thenError}) =>
		ms0 = performance.now()
		if !shouldRun deps, @state then return [null, Infinity]
		# console.log k
		# console.log 'ms1', performance.now() - ms0

		query = f @state, {}
		@queryRes[k] = query
		q0 = performance.now()
		runQueryRes = @config.runQuery {f, query, state: @state, key: k, rerun} # , meta = {isLocal, optimistic, etc..}
		msQ = performance.now() - q0
		if runQueryRes == Infinity
			return [query, Infinity, msQ]
		else if isThenable runQueryRes
			if thenError then throw thenError
			do (k) => # https://makandracards.com/makandra/38339-iifes-in-coffeescript
				return [query, runQueryRes.then (queryRes_) =>
					@dataChanges[k] = 1
					@_set k, queryRes_
				, msQ]
		else
			# console.log 'ms2', performance.now() - ms0
			@_set k, runQueryRes
			# console.log 'ms3', performance.now() - ms0
			return [query, runQueryRes, msQ]

	runSelector: ({k, f, deps}) =>
		if !shouldRun deps, @state then return [Infinity, 0]

		t0 = @config.perf()
		res = f @state
		ms = @config.perf() - t0
		resStr = JSON.stringify res
		if res == Infinity then return [Infinity, ms]
		else if @selectorRes[k] == resStr then return [Infinity, ms]
		else
			@_set k, res
			@selectorRes[k] = resStr
			return [res, ms]

	runInvoker: ({k, f, deps}) =>
		if !shouldRun deps, @state then return Infinity
		@config.runInvoker {f, key: k, state: @state, app: @}

	# TODO: HTTP 203 episode: kolla CPU och kanske optimera att raf när något ändrats bara
	# The run loop - triggering selectors and queriers based on totalChanges since last run
	run: (initial) =>
		if !initial && isEmpty(@dataChanges) && isEmpty(@totalChanges)
			@stopCurrentRun = @config.raf () => @run()
			return

		t0 = @config.perf()

		affected = [] # dir, ind, data

		invokersToRun = []

		if initial
			for {k, f, deps, isQ, isS, isI} in @qsi
				if isEmpty deps
					if isQ
						t0Q = @config.perf()
						[query, runRes, msQ1] = @runQuery {k, f, deps}
						msQ2 = @config.perf() - t0Q
						if runRes != Infinity then affected.push {k, deps, isQ, isS, isI, query, runRes, dir: 1, ms: msQ1, ms2: msQ2}
					else if isS
						[runRes, msS] = @runSelector {k, f, deps}
						if runRes != Infinity then affected.push {k, deps, isQ, isS, isI, runRes, dir: 1, ms: msS}
					else if isI
						invokersToRun.push {k, f, deps}
						affected.push {k, deps, isQ, isS, isI, runRes, dir: 1}

		savedDataChanges = clone @dataChanges
		if !isEmpty @dataChanges
			for {k, f, deps, isQ, isS, isI} in @qsi
				if !isQ then continue

				thenError = new Error "app2: query #{k} returned promise on rerun, that is not allowed"
				t0Q = @config.perf()
				[query, runRes, msQ1] = @runQuery {k, f, deps, rerun: true, thenError}
				msQ2 = @config.perf() - t0Q
				if runRes != Infinity then affected.push {k, deps, isQ, query, runRes, data: 1, ms: msQ1, ms2: msQ2}

			@dataChanges = {}


		directChanges = clone @totalChanges
		subCalls = []
		if !isEmpty @totalChanges
			for {k, f, deps, isQ, isS, isI} in @qsi
				if isEmpty deps then continue
				else if !isAffected2(deps, @totalChanges) then continue

				if isAffected2(deps, directChanges) then dir = 1; ind = null else ind = 1; dir = null
				if isQ
					t0Q = @config.perf()
					[query, runRes, msQ1] = @runQuery {k, f, deps}
					msQ2 = @config.perf() - t0Q
					if runRes != Infinity then affected.push {k, deps, isQ, isS, isI, query, runRes, dir, ind, ms: msQ1, ms2: msQ2}
				else if isS
					t0S = @config.perf()
					[runRes, msS1] = @runSelector {k, f, deps}
					msS2 = @config.perf() - t0S
					if runRes != Infinity then affected.push {k, deps, isQ, isS, isI, runRes, dir, ind, ms: msS1, ms2: msS2}
				else if isI
					invokersToRun.push {k, f, deps, dir, ind}
					# affected.push {k, deps, isQ, isS, isI, runRes, dir, ind}

			indirectChanges = diff directChanges, @totalChanges

			# NOTE: seems calling the cb can effect what is rendered and then also what subscriptions exists
			#				so sub can actually be undefined within the loop because of timing so we need to check for nil
			t0subs = @config.perf()
			for sub in @subs
				if !sub then continue
				{deps, cb} = sub
				if isAffected2 deps, @totalChanges
					subCalls.push deps
					cb @state
			msSubs = @config.perf() - t0subs

			@totalChanges = {}

		# Note that invokers not included in ms since subs are already called (and rendering has been done?!)
		ms = @config.perf() - t0
			
		for {k, f, deps, dir, ind} in invokersToRun
			t0i = @config.perf()
			@runInvoker {k, f, deps}
			msI = @config.perf() - t0i
			affected.push {k, deps, isQ: false, isS: false, isI: true, runRes: undefined, dir, ind, ms: msI}

		@config.log {type: 'run', initial, ms, msSubs, affected, state: @state, subCalls,
		directChanges, indirectChanges, dataChanges: savedDataChanges}

		@stopCurrentRun = @config.raf () => @run()
		return undefined


	rerunQuery: (k) =>
		@dataChanges[k] = 1

	rerunAllQueries: () =>
		for {k, isQ} in @qsi
			if isQ then @dataChanges[k] = 1

	# rerunQueries: () =>
	# 	if @hasDataChanges
	# 		t0 = @config.perf()
	# 		log = {}
	# 		for {k, f, deps, isQ} in @qsi
	# 			if !isQ then continue

	# 			queryRes = @config.runQuery res, {key: k, rerun: true}
	# 			if isThenable(queryRes) || isIterable queryRes
	# 				throw new Error 'app2: when queries rerun, they should return promise / iterables'
	# 			else if queryRes == Infinity then continue
	# 			else @_change k, queryRes

	# 		@hasDataChanges = false

	# 	@config.raf @rerunQueries


# Depricated?
		# # TODO: optimization: only do this in dev
		# if !isEmpty difference(keys(delta), keys(@config.initialUI))
		# 	keys = difference keys(delta), keys @config.initialUI
		# 	throw new Error "app2: trying to setUI with keys not included in initialUI: #{keys}\ndelta #{sf0 delta}"

export class AppPopsiql

export class Cache
	constructor: (config) ->
		defaultConfig =
			initialState: {}
			runLocal: (query, state) -> throw new Error 'You must supply runLocal to Cache'
			runRemote: (query, localRes) -> throw new Error 'You must supply runRemote to Cache'
			resToId: (res) -> if res?.then then '[PROMISE]' else JSON.stringify res
			queryToId: JSON.stringify
			shouldRunRemote: (sub, res, state, remoteRun) -> if remoteRun?.then then remoteRun else !remoteRun
		@config = merge defaultConfig, config
		@subs = {}
		@subId = 0
		@state = @config.initialState


export shouldRun = (deps, state) ->
	depsKV = $ state, pickAll(keys(deps))
	for k, v of depsKV # https://github.com/ramda/ramda/issues/2160
		if isNil(v) && deps[k] != 2 then return false
	return true

# https://thewebdev.info/2022/01/22/how-to-find-the-nth-occurrence-of-a-character-in-a-string-in-javascript/
indexOfNth = (string, char, nth, fromIndex = 0) ->
	indexChar = string.indexOf char, fromIndex
	if indexChar == -1 then -1
	else if nth == 1 then indexChar
	else indexOfNth string, char, nth - 1, indexChar + 1

# Extracts destructured keys from function declaration
# extractDeps ({a, b, c}) -> returns {a: 1, b: 1, c: 1}
# extractDeps2 ({a, b_}, {c}) -> returns {a: 1, b: 2}, {c: 1} # denoting that b also shouldRun when its value is nil
# Note: be specific about length because edge cases https://stackoverflow.com/a/56444672/416797
export extractDeps = (f) -> extractDeps_ f, 0
export extractDeps2 = (f) -> [extractDeps_(f, 0), extractDeps_(f, 1)]
export extractDeps3 = (f) -> [extractDeps_(f, 0), extractDeps_(f, 1), extractDeps_(f, 2)]

extractDeps_ = (f, i) ->
	deps = {}
	handler =
		get: (target, prop, receiver) ->
			if f.allowNil && f.allowNil.indexOf(prop) != -1 then deps[prop] = 2
			else deps[prop] = 1
			return {} # return {} so that ({obj}) -> obj.prop does not crash

	# Experimental!
	# Some functions might have side effects or not be able to handle being passed empty objects. So make a new
	#	function from f where we're only interested in the first lines that accesses the keys in the argument.
	# Comment in the two console.logs below and run the tests to understand what's happening.

	# NOTE: This seems to hard to get to work reliably!!

	# firstLine = f.toString().replace(/\)\s?\{.*/gs, ') {')
	# usesNoArguments = test(/\(\)\s?\{/, firstLine)
	# isModernJavascript = test(/\(\{/, firstLine)
	# if usesNoArguments
	# 	return {} 
	# else if isModernJavascript
	# 	# f2 = function({ a , b , c  }) {}
	# 	# console.log firstLine 
	# 	f2 = new Function('return ' + firstLine + '}')()
	# else
	# 	# f2 = function(_ref1) {
	# 	#	  var a = _ref1.a,
	# 	#       b = _ref1.b;
	# 	# }
	# 	nthSemiColon = indexOfNth f.toString(), ';', i+1
	# 	# console.log 'nthSemiColon', nthSemiColon
	# 	if nthSemiColon == -1
	# 		# function(t){t.skyWeeks,t.selectedWeek,t.pie} eg. from nextjs prod build
	# 		nthSemiColon = f.toString().length - 1
	# 	f2str = f.toString().substring(0, nthSemiColon) + ';\n}'
	# 	# console.log f2str 
	# 	f2 = new Function('return ' + f2str)()

	# console.log f.toString() 
	# console.log f2.toString() 


	proxy = new Proxy({}, handler)

	try
		if i == 0 then f proxy, {}, {}
		else if i == 1 then f {}, proxy, {}
		else if i == 2 then f {}, {}, proxy
	catch err
		# Some functions might have side effects or not be able to handle being passed empty objects. So we wrap a
		# try catch around and return what's in deps at the moment of catch.
		# This might still trigger some unwanted side effects at the extractDeps calling but most probably the
		# function will try to use the destructured arguments or the app as the second argument and throw then.

		# console.error err 
		# console.log 'extractDeps_ catched, returning deps so far', deps

	return deps


export validateConfig = ({initialUI, queries, selectors, invokers}) ->
	resolved = []
	resolvedKeys = {}

	if !initialUI || !queries || !selectors || !invokers
		throw new Error "app2: initialUI, queries, selectors, invokers are all required, got nil for atleast one"

	conflict = {}
	allKs = [...keys(init), ...keys(queries), ...keys(selectors), ...keys(invokers)]
	for k in allKs
		if conflict[k] then throw new Error "app2: conflicting key #{k} in initialUI, queries, selectors, invokers"
		else conflict[k] = k

	isQ = (k) -> !!queries[k]
	isS = (k) -> !!selectors[k]
	isI = (k) -> !!invokers[k]
	getType = (k) -> isQ(k) && 'query' || isS(k) && 'selector' || 'invoker'

	mix = $ {...queries, ...selectors, ...invokers},
					mapO (f, k) -> {k, f, deps: extractDeps(f), isQ: isQ(k), isS: isS(k), isI: isI(k)}


	while true
		lastLength = $ mix, keys, length
		for k, def of mix
			if isEmpty def.deps
				resolved.push {...def, deps: {}}
				resolvedKeys[k] = true
				delete mix[k]
				continue

			do ->
				for dep, n1or2 of def.deps
					if dep == k then throw new Error "app2: #{getType k} #{k} has dependency on itself"
					else if invokers[dep]
						throw new Error "app2: #{getType k} has dependency on invoker '#{dep}', invalid!"
					else if mix[dep] then return # dependent on element in mix that's not yet resolved
					else if !has(dep, initialUI) && !resolvedKeys[dep]
						throw new Error "app2: #{getType k} #{k} has dependency '#{dep}' which does not exist. Check your 
						spelling and make sure you did't forget to declare a key in initialUI."

				resolved.push def
				resolvedKeys[k] = true
				delete mix[k]
				
		if lastLength == $ mix, keys, length then break # we're not getting any further

	if lastLength > 0
		throw new Error "app2: you have a cyclical dependency in these queries and/or selectors: #{keys mix}"

	return [resolved, resolvedKeys]


# export reactBindings = (React, app) ->
# 	console.log 1, {app}

# 	useApp = (f) ->
# 		console.log 2, {app}, app?.get
# 		deps = extractDeps f
# 		initialData = app?.get deps
# 		console.log {initialData}
# 		[state, setState] = React.useState initialData || {}
# 		subscribe = React.useRef()

# 		# React.useEffect () ->
# 		# 	cb = (data) ->
# 		# 		# console.log 'useUI cb ', sf0(query), sf0(data)
# 		# 		setState data
# 		# 	return app.sub deps, cb
# 		# , [JSON.stringify deps]

# 		return state

# 	return {useApp}

ensureDeps = (deps, app, error) ->
	missing = difference keys(deps), keys(app.allKeys)
	if !isEmpty missing then throw error(missing)

isAffected2 = (deps, total) ->
	for k, v of deps
		if ! has k, total then continue
		else return true

	return false

export reactBindings = (React) ->

	App2Context = React.createContext null

	App2Provider = ({children, app}) ->
		React.createElement App2Context.Provider, {value: app}, children

	# Note: When using next.js and query strings in url, _app will render twice with
	# useRouter().isReady = false and userRouter().query = {} on first render causing state to
	# be undefined first and never getting set at second render and since new App is happening
	# twice, the sub is never triggered.
	# We could add initialData to [] of useEffect and trigger setData if needed but it has the
	# side effect of page blinking (no data first render, data second render).
	# If we add Page.getInitialProps to our page, next will not statically optimize the page and
	# therefor not render twice with a missing query the first render. So basically, if your app
	# relies alot on query for rendering, it might be a better user experience to opt out of
	# static optimization since it will give a blinky page.
	useApp = (f) ->
		app = React.useContext App2Context
		deps = extractDeps f
		# ensureDeps deps, app, (missing) ->
		# 	new Error "app2: useApp with invalid keys: #{missing}. Spelling mistake or forgot declare in initialUI?"
		initialData = app?.get deps
		# console.log {initialData}
		[state, setState] = React.useState initialData || {}
		subscribe = React.useRef()

		React.useEffect () ->
			cb = (data) -> setState data
			return app?.sub deps, cb
		, [JSON.stringify deps]

		return state

	return {App2Provider, App2Context, useApp}
