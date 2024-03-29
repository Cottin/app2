import _has from "ramda/es/has"; import _intersection from "ramda/es/intersection"; import _isEmpty from "ramda/es/isEmpty"; import _isNil from "ramda/es/isNil"; import _join from "ramda/es/join"; import _keys from "ramda/es/keys"; import _length from "ramda/es/length"; import _map from "ramda/es/map"; #auto_require: _esramda
import {change, mapO, $} from "ramda-extras" #auto_require: esramda-extras

import React, {useSyncExternalStore} from 'react'
import {useSyncExternalStoreWithSelector} from 'use-sync-external-store/shim/with-selector'

isClientSide = typeof window != 'undefined'

dummyServerSnapshot = React.createElement 'div', {}


selectorStyle = 'color: #17a02d; font-weight: 600;'
normalStyle = 'color: #6D6D6D; font-weight: 400;'

export createFlow = (initialData, selectorsDef, logCallback) ->
	data = initialData

	t0 = performance.now()
	[selectors] = prepareSelectors data, selectorsDef
	[derived, ran] = runSelectors data, {}, selectors
	initialState = {...data, ...derived}
	state = initialState
	logCallback? state
	if isClientSide then log 'INITIAL', performance.now() - t0, ran, true, null, state
	else log 'INITIAL', performance.now() - t0, ran, false, null, null

	getState = (f) -> return state

	listeners = new Set()

	subscribe = (l) ->
		listeners.add l
		return () -> listeners.delete l

	setData = (spec) ->
		t0 = performance.now()
		data = change spec, data
		[derived, ran] = runSelectors data, derived, selectors
		state = {...data, ...derived}
		logCallback? state
		log 'SET', performance.now() - t0, ran, true, spec
		listeners.forEach (l) -> l()

	setDataManually = (spec) ->
		data = change spec, data
		state = {...data, ...derived}
		listeners.forEach (l) -> l()


	useState = (f) ->
		res = useSyncExternalStoreWithSelector subscribe, getState, (-> initialState), f, shallowEq
		return res


	base = {get: getState, set: setData, use: useState, setManually: setDataManually}

	handler =
		get: (target, prop, receiver) ->
			if prop == 'state' then return state
			return target[prop]

	proxy = new Proxy(base, handler)
	return proxy


runSelectors = (data, oldDerived, selectors) ->
	newDerived = {...oldDerived}
	tempState = {...data, ...newDerived}
	ran = []
	for sel in selectors
		arg = {}
		dontRun = false
		for k, v of sel.deps
			if _isNil(tempState[k]) && v != 2 then dontRun = true
			arg[k] = tempState[k]
		if !dontRun && !shallowEq arg, sel.lastArg
			t0 = performance.now()
			res = sel.f tempState
			ran.push {k: sel.k, ms: performance.now() - t0, res}
			newDerived[sel.k] = res
			tempState[sel.k] = res
			sel.lastArg = arg

	return [newDerived, ran]

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


export prepareSelectors = (data, selectors) ->
	resolved = []
	resolvedKeys = {}

	if !data || !selectors then throw new Error "app3: declaration or selectors is nil"

	conflictingKeys = _intersection _keys(data), _keys(selectors)
	if !_isEmpty conflictingKeys then throw new Error "app3: conflicting keys: #{conflictingKeys}"

	# wrapSelector = (f, k, deps) ->
	# 	return (state) ->
	# 		t0 = performance.now()
	# 		res = f state
	# 		console.log "#{k} #{Math.round performance.now() - t0}ms" 
	# 		return res

	mix = $ selectors, mapO (f, k) ->
		deps = extractDeps f
		{k, deps, f, lastArg: null}

	while true
		lastLength = $ mix, _keys, _length
		for k, def of mix
			if _isEmpty def.deps
				resolved.push {...def, deps: {}}
				resolvedKeys[k] = true
				delete mix[k]
				continue

			do ->
				for dep, n1or2 of def.deps
					if dep == k then throw new Error "app3: #{k} has dependency on itself"
					else if mix[dep] then return # dependent on element in mix that's not yet resolved
					else if !_has(dep, data) && !resolvedKeys[dep]
						throw new Error "app3: #{k} has dependency '#{dep}' which does not exist. Check your 
						spelling and make sure you did't forget to declare a key in declaration."

				resolved.push def
				resolvedKeys[k] = true
				delete mix[k]
				
		if lastLength == $ mix, _keys, _length then break # we're not getting any further

	if lastLength > 0
		throw new Error "app3: you have a cyclical dependency in these queries and/or selectors: #{_keys mix}"

	return [resolved, resolvedKeys]
