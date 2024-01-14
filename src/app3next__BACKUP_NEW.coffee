 #auto_require: _esramda
import {diff} from "ramda-extras" #auto_require: esramda-extras

import {fromUrl, autoParseUrl} from 'comon/client/clientUtils'
import {createFlow} from './app3'
import Router from 'next/router'

isClientSide = typeof window != 'undefined'


export initializeAppNext = ({data, selectors, onStateChange, onUrlChange, onUrlChangeComplete}) ->

	app = createFlow {data, selectors, onStateChange}


	if isClientSide && false
		window.app = app
		lastUrl = url
		handleRouteChange = (nextUrl) ->
			console.log 'handleRouteChange', nextUrl
			current = lastUrl
			next = fromUrl nextUrl 
			delta = diff current, next
			onUrlChange? delta, app
			lastUrl = next
			app.set delta
			# WORKAROUND: routeChangeComplete is not always firing, but too hard to reproduce to report...
			setTimeout (-> onUrlChangeComplete? app.state), 0
		Router.router.events.on 'routeChangeStart', handleRouteChange
		
		# setTimeout (-> onUrlChangeComplete? app.state), 1000 # call once after initiation
		onUrlChangeComplete? app.state # call once after initiation
		
	# NOTE: did have error about "No router instance found. You should only use "next/router" inside the client side of your app"
	# Resolved by moving this into isClientSide but then it went away so keeping outside for now
	# onUrlChangeComplete? app.state # call once after initiation

		# WORKAROUND: ...this is how the correct way would look like if it was working stabilly
		#             To reproduce: to go /time, click circle, click circle (without much wait)
		# handleRouteChangeComplete = (newUrl) ->
		# 	console.log 'handleRouteChangeComplete', newUrl
		# 	onUrlChangeComplete? app.state
		# Router.router.events.on 'routeChangeComplete', handleRouteChangeComplete

	# onUrlChangeComplete? app.state # call once after initiation

export useApp = (f) -> app.use f
export setApp = (spec) -> app.set spec

# If you want to get a reference to app before app has been initialized, use this proxy
export getAppProxy = () ->
	handler =
		get: (target, prop, receiver) ->
			return {}
			if !app then return {}
			return app[prop]

	proxy = new Proxy({}, handler)
	return proxy

