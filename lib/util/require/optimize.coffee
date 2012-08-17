path = require 'path'
fs =   require 'fs'

_ = require 'lodash'
requirejs = require 'requirejs'

logger =    require '../logger'
requireRegister = require './register'

class Optimizer

  constructor: ->
    almondInPath  = path.join __dirname, "..", "assets", "almond.js"
    @almondText = fs.readFileSync almondInPath, "ascii"

  optimize: (config, fileName) =>
    return unless config.optimize
    return if @alreadyRunning
    @alreadyRunning = true

    files = if fileName
      logger.debug "Looking for base config files that need optimizing for file [[ #{fileName} ]]"
      requireRegister.treeBasesForFile(fileName)
    else
      requireRegister.treeBases()

    logger.debug "Mimosa found #{files.length} base config files"

    if files.length is 0
      return @alreadyRunning = false

    numFiles = files.length
    numProcessed = 0

    baseUrl = path.join config.watch.compiledDir, config.compilers.javascript.directory
    almondOutPath = path.join baseUrl, "almond.js"

    done = =>
      if ++numProcessed is numFiles
        @alreadyRunning = false
        logger.debug "Removing Almond at [[ #{almondOutPath} ]]"
        fs.unlinkSync almondOutPath if fs.existsSync almondOutPath
        logger.info "Requirejs optimization complete."

      if numProcessed > numFiles
        logger.warn "Mimosa's optimizer.done method was called too many times, #{numProcessed}, #{numFiles}"

    logger.debug "BaseUrl [[ #{baseUrl} ]], AlmondOutPath [[ #{almondOutPath} ]]"
    fs.writeFile almondOutPath, @almondText, 'ascii', (err) =>
      if err?
        done()
        return logger.error "Cannot write Almond, #{err}"
      for file in files
        runConfig = @setupConfig(config, file, baseUrl)
        logger.info "Beginning requirejs optimization for module [[ #{runConfig.include[0]} ]]"
        try
          requirejs.optimize runConfig, (buildResponse) =>
            logger.success "The compiled file [[ #{runConfig.out} ]] is ready for use.", true
            done()
        catch err
          logger.error err
          # see https://github.com/jrburke/r.js/issues/244, need to clean out require by hand
          requirejs._buildReset()
          done()

  setupConfig: (config, file, baseUrl) =>
    runConfig = _.extend({}, config.require.optimize)
    name = @_makeRelativeModulePath(file, baseUrl)

    runConfig.baseUrl = baseUrl             unless runConfig.baseUrl? or runConfig.baseUrl is null
    runConfig.mainConfigFile = file         unless runConfig.mainConfigFile? or runConfig.mainConfigFile is null
    runConfig.findNestedDependencies = true unless runConfig.findNestedDependencies? or runConfig.findNestedDependencies is null
    runConfig.include = [name]              unless runConfig.include? or runConfig.include is null
    runConfig.insertRequire = [name]        unless runConfig.insertRequire? or runConfig.insertRequire is null
    runConfig.wrap = true                   unless runConfig.wrap? or runConfig.wrap is null
    runConfig.name = 'almond'               unless runConfig.name? or runConfig.name is null
    runConfig.out = if runConfig.out
      path.join runConfig.baseUrl, runConfig.out
    else
      path.join runConfig.baseUrl, name + "-built.js"

    logger.debug "Mimosa is going to run r.js optimization with the following config:\n#{JSON.stringify(runConfig, null, 2)}"

    runConfig

  _makeRelativeModulePath: (aPath, baseUrl) ->
    aPath.replace(baseUrl + path.sep, '').replace('.js', '')

exports.optimize = new Optimizer().optimize