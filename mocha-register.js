import registerCoffee from 'coffeescript'
import register from '@babel/register'

// const registerCoffee = require('coffeescript')
// const register = require('@babel/register').default

registerCoffee.register({extensions: ['.coffee']})
register({extensions: ['.coffee', '.js']})