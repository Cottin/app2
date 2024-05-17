import _filter from "ramda/es/filter"; import _has from "ramda/es/has"; import _isNil from "ramda/es/isNil"; import _join from "ramda/es/join"; import _keys from "ramda/es/keys"; import _map from "ramda/es/map"; import _pick from "ramda/es/pick"; import _type from "ramda/es/type"; #auto_require: _esramda
import {change, mapO, $} from "ramda-extras" #auto_require: esramda-extras

import React, {useSyncExternalStore, createContext, useContext} from 'react'
import {useSyncExternalStoreWithSelector} from 'use-sync-external-store/shim/with-selector'

isClientSide = typeof window != 'undefined'

selectorStyle = 'color: #17a02d; font-weight: 600;'
normalStyle = 'color: #6D6D6D; font-weight: 400;'

AppContext = createContext()

export AppProvider = ({app, children}) ->
	React.createElement AppContext.Provider, {value: app}, children

if !performance then performance = {now: () -> Date.now()} # Trying to make it work in node v12

export createApp = ({data: initialData, select, onSelected}) ->
	data = initialData

	t0 = performance.now()
	[selected, ran] = select data
	initialState = {...data, ...selected}
	state = initialState
	time = performance.now() - t0
	onSelected? state
	if isClientSide then log 'INITIAL4', time, ran, true, null, state
	else log 'INITIAL SERVER', time, ran, false, null, null

	getState = (f) -> return state

	listeners = new Set()

	subscribe = (l) ->
		listeners.add l
		return () -> listeners.delete l

	setData = (spec) ->
		t0 = performance.now()
		data = change spec, data
		[selected, ran] = select data
		state = {...data, ...selected}
		time = performance.now() - t0
		onSelected? state
		log 'SET', time, ran, true, spec
		listeners.forEach (l) -> l()

	useState = (f) ->
		res = useSyncExternalStoreWithSelector subscribe, getState, (-> initialState), f, shallowEq
		return res

	base = {get: getState, set: setData, use: useState}

	handler =
		get: (target, prop, receiver) ->
			if prop == 'state' then return state
			return target[prop]

	proxy = new Proxy(base, handler)
	return proxy

log = (text, totMs, selectorsMs, logRes, pre, post) ->
	selText = $ selectorsMs, _map(({k}) -> k), _join ', '
	console.groupCollapsed "#{text} #{Math.round totMs}ms: %c#{selText}", selectorStyle
	if pre then console.log pre
	for sel in selectorsMs
		console.groupCollapsed "%c#{sel.k} %c#{Math.round sel.ms}ms", selectorStyle, normalStyle
		if logRes then console.log sel.res
		console.groupEnd()
	if post then console.log post
	console.groupEnd()

makeAppSelector = (deps) ->
	if _type(deps[0]) == 'Function' then deps[0]
	else _pick deps

export useApp = (deps...) ->
	app = useContext(AppContext)
	return app.use makeAppSelector deps

export useAppRef = () ->
	return useContext(AppContext)



# Adapded from https://github.com/pmndrs/zustand/blob/main/src/shallow.ts
export shallowEq = (a, b) ->
	if Object.is(a, b) then return true

	if typeof a != 'object' || a == null || typeof b != 'object' || b == null then return false

	keysA = _keys a
	if keysA.length != Object.keys(b).length then return false

	for k in keysA
		if !_has k, b then return false
		else if !Object.is(a[k], b[k]) then return false

	return true

export createSelectors = (selectors) ->
	ran = []
	ref = {globals: null}
	wrapper = (selector, k) ->
		lastState = undefined
		lastRes = undefined
		deps = extractDeps selector
		requiredDepsArr = $ deps, _filter((v) -> v == 1), _keys
		return (state) ->
			if shallowEq lastState, state then return lastRes
			for dep in requiredDepsArr
				if _isNil state[dep] then return null
			t0 = performance.now()
			res = selector state, ref.globals
			lastState = state
			lastRes = res
			ran.push {k, ms: performance.now() - t0, res}
			return res

	ret = $ selectors, mapO wrapper

	ret.startSelectors = () -> ran = []
	ret.setGlobals = (globals) -> ref.globals = globals
	ret.endSelectors = () -> return ran

	return ret


# Extracts destructured keys from function declaration
# extractDeps ({a, b, c}) -> returns {a: 1, b: 1, c: 1}
# f = ({a, b}) -> null; f.allowNil = ['b']
# extractDeps f returns {a: 1, b: 2} # denoting that b also shouldRun when its value is nil
export extractDeps = (f) -> extractDeps_ f

extractDeps_ = (f) ->
	deps = {}
	handler =
		get: (target, prop, receiver) ->
			if f.allowNil && f.allowNil.indexOf(prop) != -1 then deps[prop] = 2
			else deps[prop] = 1
			return {} # return {} so that ({obj}) -> obj.prop does not crash

	proxy = new Proxy({}, handler)


	originalConsoleLog = console.log # hack to make it it less confusing when adding console.logs to selectors
	try
		console.log = () ->
		f proxy, {}, {}
		console.log = originalConsoleLog
	catch err
		console.log = originalConsoleLog
		# Some functions might have side effects or not be able to handle being passed empty objects. So we wrap a
		# try catch around and return what's in deps at the moment of catch.
		# This might still trigger some unwanted side effects at the extractDeps calling but most probably the
		# function will try to use the destructured arguments or the app as the second argument and throw then.

		# console.error err 
		# console.log 'extractDeps_ catched, returning deps so far', deps

	return deps
