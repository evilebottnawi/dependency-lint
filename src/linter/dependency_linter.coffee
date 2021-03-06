_ = require 'lodash'
camelCase = require 'camel-case'
ERRORS = require '../errors'
minimatch = require 'minimatch'
packageJson = require '../../package.json'


class DependencyLinter

  constructor: (@config) ->
    @devFiles = _.concat @config.executedModules.shellScripts.dev, @config.requiredModules.files.dev
    @ignoreErrors = {}
    for key, value of ERRORS
      @ignoreErrors[value] = @config.ignoreErrors[camelCase key]

  # Lints the used and listed modules
  #
  # listedModules - {dependencies, devDependencies} where each is an array of module names
  # usedModules - array of {name, files, scripts}
  #
  # Returns {dependencies, devDependencies}
  #         where each is an array of {name, files, scripts, error, warning}
  lint: ({listedModules, usedModules}) =>
    out =
      dependencies: []
      devDependencies: []

    for usedModule in usedModules
      status =
        isDependency: not @isDevDependency usedModule
        listedAsDependency: usedModule.name in listedModules.dependencies
        listedAsDevDependency: usedModule.name in listedModules.devDependencies
      @parseUsedModule usedModule, status, out

    for key, modules of listedModules
      for name in modules when not _.some(usedModules, (moduleData) -> moduleData.name is name)
        listedModule = {name}
        if key isnt 'devDependencies' or name isnt packageJson.name
          listedModule.error = ERRORS.UNUSED
        out[key].push listedModule

    for key, results of out
      results.forEach (result) =>
        result.errorIgnored = true if result.error and @isErrorIgnored result
      out[key] = _.sortBy results, 'name'

    out


  isErrorIgnored: ({error, name}) ->
    _.some @ignoreErrors[error], (regex) -> name.match regex


  isDevDependency: ({files, scripts}) ->
    _.every(files, @isDevFile) and _.every(scripts, @isDevScript)


  isDevFile: (file) =>
    _.some @devFiles, (pattern) -> minimatch file, pattern


  isDevScript: (script) =>
    _.some @config.executedModules.npmScripts.dev, (regex) -> script.match regex


  parseUsedModule: (usedModule, status, result) ->
    {isDependency, listedAsDependency, listedAsDevDependency} = status
    if isDependency
      if listedAsDependency
        result.dependencies.push usedModule
      if listedAsDevDependency
        result.devDependencies.push _.assign {}, usedModule, {error: ERRORS.SHOULD_BE_DEPENDENCY}
      unless listedAsDependency or listedAsDevDependency
        result.dependencies.push _.assign {}, usedModule, {error: ERRORS.MISSING}
    else
      if listedAsDependency
        result.dependencies.push _.assign {}, usedModule, {error: ERRORS.SHOULD_BE_DEV_DEPENDENCY}
      if listedAsDevDependency
        result.devDependencies.push usedModule
      unless listedAsDependency or listedAsDevDependency
        result.devDependencies.push _.assign {}, usedModule, {error: ERRORS.MISSING}


module.exports = DependencyLinter
