import map from "ramda/es/map"
import {$} from "ramda-extras" #auto_require: esramda-extras

import {deepEq, eq, throws} from 'comon/shared/testUtils'

import * as app3 from './app3'


describe 'app3', () ->
	describe 'extractDeps', () ->
		it '1', () ->
			deepEq {a: 1, b: 1, c: 1}, app3.extractDeps ({a, b, c}) ->
		it '2', () ->
			deepEq [{a: 1, b: 1}, {c: 1}, {d: 1, e: 1}], app3.extractDeps3 ({a, b}, {c}, {d, e}) ->
		it '3', () ->
			deepEq {a: 1}, app3.extractDeps ({a}) -> a.prop
		it '4', () ->
			deepEq {a: 1, b: 1}, app3.extractDeps ({a, b}) -> throw new Error 'Error!'
		it '5', () ->
			deepEq [{a: 1, b: 1, c: 1}, {d: 1}], app3.extractDeps2 ({a, b, c}, {d}, o) -> throw new Error 'Error!'
		it '6', () ->
			deepEq {}, app3.extractDeps () -> throw new Error 'Error!'
		it '7', () ->
			fn = new Function('return function myFunction() { throw new Error("Error!"); }')()
			deepEq {}, app3.extractDeps fn

	describe 'prepareSelectors', () ->
		data = {a: 1, b: 2, c: null}
		depsAndK = (xs) -> $ xs, map ({deps, k}) -> {deps, k}

		it '1 easy', () ->
			[res] = app3.prepareSelectors data, {s1: ({a}) ->}
			deepEq [{deps: {a: 1}, k: 's1'}], depsAndK res

		it '2 medium', () ->
			selectors =
				q1: ({a}) ->
				q2: ({q1}) ->
				s1: ({q1, q2}) ->
				s2: ({c, s1}) ->
				i1: ({b, s2}) ->

			selectors.s1.allowNil = ['q1']

			expected = [
				{deps: {a: 1}, k: 'q1'}
				{deps: {q1: 1}, k: 'q2'}
				{deps: {q1: 2, q2: 1}, k: 's1'}
				{deps: {c: 1, s1: 1}, k: 's2'}
				{deps: {b: 1, s2: 1}, k: 'i1'}
			]
			deepEq expected, depsAndK app3.prepareSelectors(data, selectors)[0]

		it '3 itself', () ->
			selectors =
				q1: ({q1}) ->
			throws /has dependency on itself/, -> app3.prepareSelectors data, selectors

		it '4 conflicting key', () ->
			selectors =
				a: ({b}) ->
			throws /conflicting key/, -> app3.prepareSelectors data, selectors

		it '5 cyclical', () ->
			selectors =
				q1: ({s1}) ->
				s1: ({q1}) ->
			throws /cyclical/, -> app3.prepareSelectors data, selectors


