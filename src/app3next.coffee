import _map from "ramda/es/map"; #auto_require: _esramda
import {diff, $} from "ramda-extras" #auto_require: esramda-extras

import {fromUrl, autoParseUrl} from 'comon/client/clientUtils'
import {createFlow} from './app3'
import Router from 'next/router'

isClientSide = typeof window != 'undefined'

app = null # singleton

export createInitializeApp = ({data, selectors, onUrlChange, onUrlChangeComplete, logCallback}) -> (query = {}, force = false, overrideData = null) ->
	# We need to force new initialization on server to re-render the page from current url on refresh, otherwise
	# where will be a miss-match between client and server html.
	# If two users reloads at the same time, will both be rendered with the same singleton?
	# Don't know how to test that but the solution would probably be to use a <Provider> instead.
	if app && !force then return

	url = $ query, _map(autoParseUrl)
	dataToUse = if overrideData then {...data, ...overrideData} else data
	app = createFlow {...dataToUse, ...url}, selectors, logCallback

	if isClientSide
		window.app = app
		lastUrl = url
		handleRouteChange = (nextUrl) ->
			current = lastUrl
			next = fromUrl nextUrl 
			delta = diff current, next
			onUrlChange? delta, app
			lastUrl = next
			app.set delta
			# WORKAROUND: routeChangeComplete is not always firing, but too hard to reproduce to report...
			setTimeout (-> onUrlChangeComplete? app.state), 0
		Router.router.events.on 'routeChangeStart', handleRouteChange
		
	# NOTE: did have error about "No router instance found. You should only use "next/router" inside the client side of your app"
	# Resolved by moving this into isClientSide but then it went away so keeping outside for now
	onUrlChangeComplete? app.state # call once after initiation

		# WORKAROUND: ...this is how the correct way would look like if it was working stabilly
		#             To reproduce: to go /time, click > and < in timeline, click circle, click > and < in report
		#                           click circle and watch routeChangeStart fire but not routeChangeComplete.
		#                           Also verified bug in production.
		# handleRouteChangeComplete = (newUrl) ->
		#   console.log 'handleRouteChangeComplete', newUrl
		#   onUrlChangeComplete? app.state
		# Router.router.events.on 'routeChangeComplete', handleRouteChangeComplete

export useApp = (f) -> app.use f
export setApp = (spec) -> app.set spec

# If you want to get a reference to app before app has been initialized, use this proxy
export getAppProxy = () ->
	handler =
		get: (target, prop, receiver) ->
			if !app then return {}
			return app[prop]

	proxy = new Proxy({}, handler)
	return proxy

