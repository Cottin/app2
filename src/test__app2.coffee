import clone from "ramda/es/clone"; import filter from "ramda/es/filter"; import has from "ramda/es/has"; import head from "ramda/es/head"; import invoker from "ramda/es/invoker"; import keys from "ramda/es/keys"; import map from "ramda/es/map"; import mergeRight from "ramda/es/mergeRight"; import pickAll from "ramda/es/pickAll"; import toPairs from "ramda/es/toPairs"; import without from "ramda/es/without"; #auto_require: esramda
import {$} from "ramda-extras" #auto_require: esramda-extras

import * as app2 from './app2'

import {deepEq, eq, throws} from 'comon/shared/testUtils'


describe 'app2', () ->
	describe 'extractDeps', () ->
		it '1', () ->
			deepEq {a: 1, b: 1, c: 1}, app2.extractDeps ({a, b, c}) ->
		it '2', () ->
			deepEq [{a: 1, b: 1}, {c: 1}, {d: 1, e: 1}], app2.extractDeps3 ({a, b}, {c}, {d, e}) ->
		it '3', () ->
			deepEq {a: 1}, app2.extractDeps ({a}) -> a.prop
		it '4', () ->
			deepEq {a: 1, b: 1}, app2.extractDeps ({a, b}) -> throw new Error 'Error!'
		it '5', () ->
			deepEq [{a: 1, b: 1, c: 1}, {d: 1}], app2.extractDeps2 ({a, b, c}, {d}, o) -> throw new Error 'Error!'
		it '6', () ->
			deepEq {}, app2.extractDeps () -> throw new Error 'Error!'
		it '7', () ->
			fn = new Function('return function myFunction() { throw new Error("Error!"); }')()
			deepEq {}, app2.extractDeps fn

	describe 'shouldRun', () ->
		it '1', () -> eq true, app2.shouldRun {a: null, b: null}, {a: 1, b: 2}
		it '2', () -> eq false, app2.shouldRun {a: null, b: null}, {a: null, b: 2}
		it '3', () -> eq false, app2.shouldRun {a: null, b: null}, {a: undefined, b: 2}
		it '4', () -> eq false, app2.shouldRun {a: null, b: null}, {a: 1}

	describe 'validateConfig', () ->
		initialUI = {a: 1, b: 2, c: null}
		depsAndK = (xs) -> $ xs, map ({deps, k}) -> {deps, k}

		it '1 easy', () ->
			[res] = app2.validateConfig {initialUI, queries: {q1: ({a}) ->}, selectors: {}, invokers: {}}
			deepEq [{deps: {a: 1}, k: 'q1'}], depsAndK res

		it '2 medium', () ->
			config =
				initialUI: initialUI
				queries:
					q1: ({a}) ->
					q2: ({q1}) ->
				selectors:
					s1: ({q1, q2}) ->
					s2: ({c, s1}) ->
				invokers:
					i1: ({b, s2}) ->

			config.selectors.s1.allowNil = ['q1']

			expected = [
				{deps: {a: 1}, k: 'q1'}
				{deps: {q1: 1}, k: 'q2'}
				{deps: {q1: 2, q2: 1}, k: 's1'}
				{deps: {c: 1, s1: 1}, k: 's2'}
				{deps: {b: 1, s2: 1}, k: 'i1'}
			]
			deepEq expected, depsAndK app2.validateConfig(config)[0]

		it '3 itself', () ->
			config =
				initialUI: initialUI
				queries:
					q1: ({q1}) ->
				selectors: {}
				invokers: {}
			throws /has dependency on itself/, -> app2.validateConfig config

		it '4 conflicting key', () ->
			config =
				initialUI: initialUI
				queries:
					q1: ({b}) ->
				selectors:
					q1: ({a}) ->
				invokers: {}
			throws /conflicting key/, -> app2.validateConfig config

		it '5 cyclical', () ->
			config =
				initialUI: initialUI
				queries:
					q1: ({s1}) ->
				selectors:
					s1: ({q1}) ->
				invokers: {}
			throws /cyclical/, -> app2.validateConfig config

		it '6 dependency on invoker', () ->
			config =
				initialUI: initialUI
				queries:
					q1: ({b}) ->
				selectors:
					s1: ({i1}) ->
				invokers:
					i1: ({q1}) ->
			throws /dependency on invoker/, -> app2.validateConfig config


	describe 'app2', () ->
		initialUI = {a: 1, b: 2, c: null}
		queryMemo = {}
		ref = {app: null, cacheVer: 0}
		cache =
			o: {1: {x: 1}, 2: {x: 2}, 3: {x: 3}, 4: {x: 4}, 5: {x: 5}, 6: {x: 6}, 7: {x: 7}, 8: {x: 8}}
			p: {1: {y: 1}, 2: {y: 2}, 3: {y: 3}, 4: {y: 4}, 5: {y: 5}, 6: {y: 6}, 7: {y: 7}, 8: {y: 8}}
		fakeRunQuery = (query, {data} = {}) ->
			# In real world, we would run the query on the current cache state
			[k, v] = $ query, toPairs, head
			res = cache[k][v]
			if data then res.v = ref.cacheVer
			return res
		runQuery = (log) -> ({f, state, key, rerun}) ->
			[_, {data, prom}] = app2.extractDeps2 f
			query = f state, {}

			# resMemo = JSON.stringify res
			# if queryMemo[key] == resMemo then res = Infinity
			# else queryMemo[key] = resMemo

			res = fakeRunQuery query, {data}
			resMemo = JSON.stringify res
			# console.log "runQuery #{key} #{sf0 query} #{sf0 res} rerun: #{rerun && 1 || 0} data: #{data && 1 || 0} prom: #{prom && 1 || 0} 
			#{if queryMemo[key] == resMemo then 'Infinity' else ''}", res
			if queryMemo[key] == resMemo
				log.push ["#{rerun && 're-' || ''}runQuery - #{key}", Infinity]
				return Infinity
			queryMemo[key] = resMemo

			log.push ["#{rerun && 're-' || ''}runQuery - #{key}", clone res]

			if rerun then return res
			else if prom
				new Promise (resolve) -> setTimeout (() ->
					ref.cacheVer++
					# console.log  "resolveQuery - #{key} #{sf0 res}"
					log.push ["resolveQuery - #{key}", res]
					resolve(res)), 0
			else res

		runInvoker = (log, ref) -> ({f, state, key}) ->
			# console.log 'runInvoker' 
			log.push ["runInvoker - #{key}"]
			log.push ["setUI", {c: 1}]
			ref.app.setUI {b: 1}

		logger = (log) -> (o) ->
			dir = $ o.affected, filter((x) -> !!x.dir), map ({k, isQ}) -> k
			ind = $ o.affected, filter((x) -> !!x.ind), map ({k, isQ}) -> k
			dat = $ o.affected, filter((x) -> !!x.data), map ({k, isQ}) -> k

			if o.type == 'run'
				log.push ["log - RUN: #{dir} | #{ind} | #{dat}", clone o.state]
				# log.push ["log - RUN: #{o.directAffected} | #{o.indirectAffected}", clone o.state]
			else if o.type == 'run queries'
				log.push ["log - RUN QUERIES: #{o.ranQueries}"]
			else throw new Error 'NYI'
		fakeRaf = (log) -> (runs, cb, uiChanges, ref) ->
			counter = 0
			(f) ->
				console.log "----------- RUN #{counter} ------------"
				if counter == runs then return cb()
				if uiChanges[counter]
					log.push ["setUI", uiChanges[counter]]
					ref.app.setUI uiChanges[counter]
				setTimeout f, 10
				counter++
		perf = () -> Math.floor process.uptime() * 1000
		setupMock = (log, runs, uiChanges, ref) ->
			raf = null
			done = new Promise (res) -> raf = fakeRaf(log) runs, res, uiChanges, ref
			done.catch (err) -> console.error err
			mock = {initialUI, runQuery: runQuery(log), log: logger(log), raf, perf, runInvoker: runInvoker(log, ref)}
			return [done, mock]

		fakeSub = (log, app, i, deps) ->
			app.sub deps, (state) ->
				data = pickAll keys(deps), state
				log.push ["sub #{i}", data]

		it '1', () ->
			log = []
			[done, mock] = setupMock(log, 7, {1: {a: 2}, 2: {b: 3}, 3: {c: 0}}, ref)
			config = mergeRight mock,
				queries:
					q0: () -> {o: 1}
					q1: ({a}) -> {o: a+1}
					q2: ({s1}, {data}) -> {p: s1+1}
					q3: ({a, c, s2}, {prom}) -> {o: a + c + s2}
				selectors:
					s1: ({b}) -> b+1
					s2: ({c}) -> c+1
					s3: ({q3}) -> q3.x+1
					s4: ({s3}) -> s3+1
				invokers:
					i1: ({s4}) -> 

			app = new app2.App config
			ref.app = app
			fakeSub log, app, 1, {a: 1, b: 1, s1: 1}
			fakeSub log, app, 2, {s3: 1}
			app.start()
			await done

			assertLog log, [
				["runQuery - q0", {x: 1}],
				["runQuery - q1", {x: 2}],
				["runQuery - q2", {y: 4, v: 0}],
				["sub 1", {a: 1, b: 2, s1: 3}]
				["log - RUN: q0,q1,s1 | q2 | ", {a: 1, b: 2, c: null, s1: 3, q0: {x: 1}, q1: {x: 2}, q2: {y: 4, v: 0}}],
				["setUI", {a: 2}],
				["runQuery - q1", {x: 3}],
				["sub 1", {a: 2, b: 2, s1: 3}]
				["log - RUN: q1 |  | ", {a: 2, b: 2, c: null, s1: 3, q0: {x: 1}, q1: {x: 3}, q2: {y: 4, v: 0}}],
				["setUI", {b: 3}],
				["runQuery - q2", {y: 5, v: 0}],
				["sub 1", {a: 2, b: 3, s1: 4}]
				["log - RUN: s1 | q2 | ", {a: 2, b: 3, c: null, s1: 4, q0: {x: 1}, q1: {x: 3}, q2: {y: 5, v: 0}}],
				["setUI", {c: 0}],
				["runQuery - q3", {x: 3}],
				["log - RUN: s2,q3 |  | ", {a: 2, b: 3, c: 0, s1: 4, s2: 1, q0: {x: 1}, q1: {x: 3}, q2: {y: 5, v: 0}}],
				["resolveQuery - q3", {x: 3}],
				["re-runQuery - q0", Infinity],
				["re-runQuery - q1", Infinity],
				["re-runQuery - q2", {y: 5, v: 1}],
				["re-runQuery - q3", Infinity],
				["sub 2", {s3: 4}]
				["runInvoker - i1"]
				["setUI", {c: 1}],
				["log - RUN: s3 | s4,i1 | q2", {a: 2, b: 1, c: 0, s1: 4, s2: 1, s3: 4, s4: 5, q0: {x: 1}, q1: {x: 3}, q2: {y: 5, v: 1}, q3: {x: 3}}],
				["runQuery - q2", {y: 3, v: 1}],
				["sub 1", {a: 2, b: 1, s1: 2}]
				["log - RUN: s1 | q2 | ", {a: 2, b: 1, c: 0, s1: 2, s2: 1, s3: 4, s4: 5, q0: {x: 1}, q1: {x: 3}, q2: {y: 3, v: 1}, q3: {x: 3}}],
			]


assertLog = (log, expected) ->
	for line, i in log
		deepEq expected[i] || ['Add another line'], line, "Line #{i} !!!!" # hard to debug without the line

	eq log.length, expected.length, 'expected is too long!'



			# if ref.hasDataChanges
			# 	if $ key, test(/Flop$/)
			# 		return {[replace(/Flop/, 'Flip', key)]: query[key]}
			# 	else if $ query, keys, head, test(/Flip$/)
			# 		return {[replace(/Flip/, 'Flop', key)]: query[key]}
