React = require 'react'
_ = require 'underscore'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI, Utils} = require 'nylas-exports'

OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'
Providers = require './account-types'
url = require 'url'

class AccountChoosePage extends React.Component
  @displayName: "AccountChoosePage"

  constructor: (@props) ->
    @state =
      email: ""
      provider: ""
      environment: NylasApiEnvironmentStore.getEnvironment()

  componentDidMount: ->
    @_usub = NylasApiEnvironmentStore.listen =>
      @setState environment: NylasApiEnvironmentStore.getEnvironment()

  componentWillUnmount: ->
    @_usub?()

  render: =>
    <div className="page account-choose">
      <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
        <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

      <RetinaImg url="nylas://onboarding/assets/nylas-pictograph@2x.png" mode={RetinaImg.Mode.ContentIsMask} style={zoom: 0.29} className="logo"/>

      <div className="caption" style={marginTop: 15, marginBottom:20}>Select your email provider</div>

      {@_renderProviders()}

    </div>

  _renderProviders: ->
    return Providers.map (provider) =>
      <div className={"provider "+provider.name} key={provider.name} onClick={=>@_onChooseProvider(provider)}>

        <div className="icon-container">
          <RetinaImg name={provider.icon} mode={RetinaImg.Mode.ContentPreserve} className="icon"/>
        </div>
        <span className="provider-name">{provider.displayName}</span>
      </div>

  _renderError: ->
    if @state.error
      <div className="alert alert-danger" role="alert">
        {@state.error}
      </div>
    else <div></div>

  _onEmailChange: (event) =>
    @setState email: event.target.value

  _onChooseProvider: (provider) =>
    if provider.name is 'gmail'
      # Show the "Sign in to Gmail" prompt for a moment before actually bouncing
      # to Gmail. (400msec animation + 200msec to read)
      _.delay =>
        @_onBounceToGmail(provider)
      , 600
    OnboardingActions.moveToPage("account-settings", {provider})

  _base64url: (buf) ->
    # Python-style urlsafe_b64encode
    buf.toString('base64')
      .replace(/\+/g, '-') # Convert '+' to '-'
      .replace(/\//g, '_') # Convert '/' to '_'

  _onBounceToGmail: (provider) =>
    crypto = require 'crypto'

    # Client key is used for polling. Requirements are that it not be guessable
    # and that it never collides with an active key (keys are active only between
    # initiating gmail auth and successfully requesting the account data once.
    provider.clientKey = @_base64url(crypto.randomBytes(40))

    # Encryption key is used to AES encrypt the account data during storage on the
    # server.
    provider.encryptionKey = crypto.randomBytes(24)
    provider.encryptionIv = crypto.randomBytes(16)
    code = "aaa" #atom.config.get("inviteCode")
    shell = require 'shell'
    googleUrl = url.format({
      protocol: 'https'
      host: 'accounts.google.com/o/oauth2/auth'
      query:
        response_type: 'code'
        state: [provider.clientKey,@_base64url(provider.encryptionKey),@_base64url(provider.encryptionIv),code].join(',')
        client_id: '372024217839-cdsnrrqfr4d6b4gmlqepd7v0n0l0ip9q.apps.googleusercontent.com'
        redirect_uri: "#{EdgehillAPI.APIRoot}/oauth/google/callback"
        access_type: 'offline'
        scope: 'https://www.googleapis.com/auth/userinfo.email \
            https://www.googleapis.com/auth/userinfo.profile \
            https://mail.google.com/ \
            https://www.google.com/m8/feeds \
            https://www.googleapis.com/auth/calendar'
        approval_prompt: 'force'
    })
    shell.openExternal(googleUrl)

  _environmentComponent: =>
    return <div></div> unless atom.inDevMode()
    <div className="environment-selector">
      <select value={@state.environment} onChange={@_onEnvChange}>
        <option value="development">Development (edgehill-dev, api-staging)</option>
        <option value="experimental">Experimental (edgehill-experimental, api-experimental)</option>
        <option value="staging">Staging (edgehill-staging, api-staging)</option>
        <option value="production">Production (edgehill, api)</option>
      </select>
    </div>

  _onEnvChange: (event) =>
    OnboardingActions.changeAPIEnvironment(event.target.value)

module.exports = AccountChoosePage
