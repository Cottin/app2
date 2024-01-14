import _has from "ramda/es/has"; import _intersection from "ramda/es/intersection"; import _isEmpty from "ramda/es/isEmpty"; import _keys from "ramda/es/keys"; import _length from "ramda/es/length"; #auto_require: _esramda
import {change, mapO, $} from "ramda-extras" #auto_require: esramda-extras

import React, {useSyncExternalStore} from 'react'

dummyServerSnapshot = React.createElement 'div', {}

data = {a: 5, b: 5}
listeners = []

export createFlow = (initialData, selectors) ->

	getData = () ->
		console.log 'getData', data
		return data


	memo = new Map()
	subscribe = (f) ->
		console.log 'memo', memo
		if memo.has(f) then return memo.get(f)
		else 
			newListener = (l) ->
				console.log 'subscribe' 
				listeners = [...listeners, l]
				return () ->
					console.log 'unsubscribe' 
					listeners = listeners.filter (list) -> list != l
			memo.set(f, newListener)
			return newListener

	changeData = (spec) ->
		data = change spec, data
		console.log 'changeData', {spec, data}
		listeners.forEach (l) -> l()

	useData = (f) ->
		res = useSyncExternalStore subscribe(f), getData, -> dummyServerSnapshot
		return res


	return {get: getData, change: changeData, use: useData}# sub: subscribe, 


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


export prepareSelectors = ({data, selectors}) ->
	resolved = []
	resolvedKeys = {}

	if !data || !selectors then throw new Error "app3: declaration or selectors is nil"

	conflictingKeys = _intersection _keys(data), _keys(selectors)
	if !_isEmpty conflictingKeys then throw new Error "app3: conflicting keys: #{conflictingKeys}"

	wrapSelector = (f, k, deps) ->
		return (state) ->
			t0 = performance.now()
			res = f state
			console.log "#{k} #{Math.round performance.now() - t0}ms" 
			return res

		# console.log 'deps', deps
		# lastArg = {}
		# return (arg) ->
		# 	for k, v of deps
		# 		if lastArg[k] != arg[k]






	mix = $ selectors, mapO (f, k) ->
		deps = extractDeps f
		{k, deps, f: wrapSelector f, k, deps}

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
