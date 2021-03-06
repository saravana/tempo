gem "buildr"

require "rubygems"
require "buildr"
require "rsc/buildr-tasks/xmlbeans"
# require "tasks/xmlbeans"

# Keep this structure to allow the build system to update version numbers.
VERSION_NUMBER = "5.2.1.2-SNAPSHOT"
NEXT_VERSION = "5.2.1.3"

require "rsc/build/dependencies.rb"
require "rsc/build/repositories.rb"
# leave this require after dependencies.rb so the same jpa version is used throughout the whole build
require "rsc/buildr-tasks/openjpa"
require "rsc/buildr-tasks/generate_sql"

# revert to buildr tasks when we can use buildr 1.3
# require "tasks/easyb"
require "buildr/cobertura"

desc "Tempo Workflow"
define "tempo" do
  project.version = VERSION_NUMBER
  project.group = "org.intalio.tempo"

  # compile.options.source = "1.5"
  compile.options.target = "1.5"

  define "cas-server-webapp" do
    libs = projects("security", "security-ws-client", "security-ws-common"), AXIOM, AXIS2, CAS_LIBS, 
    	APACHE_COMMONS[:beanutils], APACHE_COMMONS[:codec], APACHE_COMMONS[:discovery], APACHE_COMMONS[:httpclient], 
    	APACHE_COMMONS[:logging], APACHE_COMMONS[:lang], LOG4J, WS_COMMONS_SCHEMA, JSTL, TAGLIBS
    compile.with libs
    package(:war).with :libs=>libs
  end
  
  define "dao-nutsNbolts" do
    compile.with project("web-nutsNbolts"), APACHE_JPA, SLF4J
    package :jar
  end
   
  define "dao-tools" do
    compile.with projects("security", "security-ws-client", "tms-axis", "tms-common", "tms-service", "wds-service", "tms-client", "web-nutsNbolts", "dao-nutsNbolts"), 
    APACHE_DERBY, 
    APACHE_JPA, 
    AXIOM, 
    AXIS2, 
    DOM4J,
    JAXEN, 
    JYAML,
    LOG4J, 
    DB_CONNECTOR.values, 
    SLF4J, 
    SPRING[:core], 
    SERVLET_API, 
    STAX_API, 
    XMLBEANS

    test.with projects("tms-common"), APACHE_COMMONS[:pool], CASTOR, SUNMAIL, WSDL4J, WS_COMMONS_SCHEMA, WOODSTOX, XERCES
    unless ENV["MIGRATE"] == 'yes'
      test.exclude '*JDBC2JPAConverterTest*'
    end
    package :war
  end
  
  desc "Deployment API"
  define "deploy-api" do
    compile.with project("registry"), SLF4J
    package :jar
  end

  desc "Deployment Service Implementation"
  define "deploy-impl" do
    compile.with projects("deploy-api", "web-nutsNbolts"), SERVLET_API, SLF4J, SPRING[:core]
    test.with LOG4J, XERCES
    test.exclude '*TestUtils*'
    package :jar
  end

  desc "Deployment Web-Service Common Library"
  define "deploy-ws-common" do
    compile.with projects("deploy-api", "deploy-impl", "registry"), AXIOM, AXIS2, SUNMAIL, SLF4J, SPRING[:core], STAX_API 
    package(:jar)
  end
  
  desc "Deployment Web-Service Client"
  define "deploy-ws-client" do
    compile.with projects("deploy-api", "deploy-ws-common"), 
                 AXIOM, AXIS2, SLF4J, STAX_API, SPRING[:core]
    test.with project("deploy-impl"), APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], LOG4J, SUNMAIL, XERCES, WS_COMMONS_SCHEMA, WSDL4J, WOODSTOX 

    # Remember to set JAVA_OPTIONS before starting Jetty
    # export JAVA_OPTIONS=-Dorg.intalio.tempo.configDirectory=/home/boisvert/svn/tempo/security-ws2/src/test/resources
    
    # require live Axis2 instance
    if ENV["LIVE"] == 'yes'
      LIVE_ENDPOINT = "http://localhost:8080/axis2/services/DeploymentService"
    end
    
    if defined? LIVE_ENDPOINT
      test.using :properties => 
        { "org.intalio.tempo.deploy.ws.endpoint" => LIVE_ENDPOINT,
          "org.intalio.tempo.configDirectory" => _("src/test/resources") }
    end

    package(:jar).tap do |jar|
      jar.with :meta_inf => project("deploy-ws-service").path_to("src/main/axis2/*.wsdl")
    end
  end

  desc "Deployment Web-Service"
  define "deploy-ws-service" do
    package(:aar).with :libs => [ projects("deploy-api", "deploy-impl", "deploy-ws-common", "registry"), SLF4J, SPRING[:core] ]
  end

  desc "Form Dispatcher Servlet"
  define "fds" do
    libs = [AXIS2, APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], DOM4J, LOG4J, SERVLET_API, SLF4J, STAX_API]
    compile.with libs 
    resources.filter.using "version" => VERSION_NUMBER
    test.with JAXEN, XMLUNIT
    unless ENV["LIVE"] == 'yes'
      test.exclude '*RemoteFDSTest*'
    end
    package(:war).with(:libs=>[libs,JAXEN])
  end

  desc "Workflow Forms"
  define "forms" do
    define "AbsenceRequest" do
      package(:zip).path("AbsenceRequest.pipa").include(_("src/main/pipa/*"))
      package(:zip).path("AbsenceRequest.xform").include(_("src/main/xform/*"))
    end
  end
  
  desc "Workflow Processes"
  define "processes" do
    define "xpath-extensions" do
      package(:jar)
    end
    
    define "AbsenceRequest" do
      package(:jar)
    end
    
    define "TaskManager" do
      package(:jar)
    end
    
    define "Store" do
      package(:jar)
    end
    
    define "peopleActivity" do
      package(:jar)
    end
  end

  desc "Security Framework"
  define "security" do
    compile.with CAS_CLIENT, DOM4J, CASTOR, LOG4J, SLF4J, SPRING[:core], XERCES

    test.exclude "*BaseSuite"
    test.exclude "*FuncTestSuite"
    test.exclude "*ldap*"

    package :jar
  end
  
  desc "Security Web-Service Common Library"
  define "security-ws-common" do
    compile.with project("security"), AXIOM, AXIS2, SLF4J, SPRING[:core], STAX_API 
    package(:jar)
  end
  
  desc "Security Web-Service Client"
  define "security-ws-client" do
    compile.with projects("security", "security-ws-common"),AXIOM, AXIS2, SLF4J, STAX_API, SPRING[:core]
    test.with APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], CASTOR, LOG4J, SUNMAIL, XERCES, WS_COMMONS_SCHEMA, WSDL4J, WOODSTOX 

    # Remember to set JAVA_OPTIONS before starting Jetty
    # export JAVA_OPTIONS=-Dorg.intalio.tempo.configDirectory=/home/boisvert/svn/tempo/security-ws2/src/test/resources
    
    # require live Axis2 instance
    if ENV["LIVE"] == 'yes'
      LIVE_ENDPOINT = "http://localhost:8080/axis2/services/TokenService"
    end
    
    if defined? LIVE_ENDPOINT
      test.using :properties => 
        { "org.intalio.tempo.security.ws.endpoint" => LIVE_ENDPOINT,
          "org.intalio.tempo.configDirectory" => _("src/test/resources") }
    end

    package(:jar).tap do |jar|
      jar.with :meta_inf => project("security-ws-service").path_to("src/main/axis2/*.wsdl")
    end
  end

  
  desc "Security Web-Service"
  define "security-ws-service" do
    compile.with projects("security", "security-ws-common"), AXIOM, AXIS2, SLF4J, SPRING[:core], STAX_API  
    package(:aar).with :libs => [ projects("security", "security-ws-common"), CASTOR, SLF4J, SPRING[:core], CAS_CLIENT ]
  end
  
  desc "Task Attachment Service"
  define "tas-service" do
    compile.with projects("security", "security-ws-client"), 
                 APACHE_COMMONS[:httpclient], AXIOM, AXIS2, JAXEN, SLF4J, STAX_API

    test.with APACHE_COMMONS[:codec], LOG4J, SUNMAIL, WSDL4J, WS_COMMONS_SCHEMA, WOODSTOX
    test.exclude '*TestUtils*'

    # require live Axis2 instance
    unless ENV["LIVE"] == 'yes'
      test.exclude '*Axis2TASService*'
      test.exclude '*WDSStorageTest*'
    end

    package(:jar)
    
    package(:aar).with(:libs => [ 
        projects("security", "security-ws-client", "security-ws-common", "web-nutsNbolts"), APACHE_COMMONS[:httpclient], JAXEN, SLF4J, SPRING[:core]])
  end

  desc "Xml Beans generation"
  define "tms-axis" do 
    FileUtils.mkdir_p _('target/classes/') # workaround for bug in buildr when no classes to be compiled.
    compile_xml_beans _("../tms-service/src/main/axis2")
    package(:jar).include _('target/generated/xmlbeans/'), :as=>'.'
    package(:jar).include _('target/classes/'), :as=>'.' 

  end

  desc "Task Management Services Common Library"
  define "tms-common" do |project|
    compile.with projects("security", "security-ws-client", "tms-axis"), APACHE_JPA, APACHE_COMMONS[:pool], APACHE_COMMONS[:collections], AXIS2, AXIOM, DOM4J, JAXEN, SLF4J, SPRING[:core], STAX_API, XERCES, XMLBEANS
    
    compile { open_jpa_enhance }
    
    task "package" => generate_sql([project], "workflow.tms")
    
    test.with APACHE_DERBY, LOG4J, DB_CONNECTOR.values, XMLUNIT, WOODSTOX
    test.exclude '*TestUtils*'
    
    package(:jar)
  end
  
  desc "Task Management Service Client"
  define "tms-client" do
    compile.with projects("tms-axis", "tms-common"), 
      APACHE_JPA, AXIOM, AXIS2, SLF4J, STAX_API, WSDL4J, WS_COMMONS_SCHEMA, XMLBEANS

    test.with APACHE_COMMONS[:pool], APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], LOG4J, WOODSTOX, SUNMAIL
    test.exclude '*TestUtils*'

    unless ENV["LIVE"] == 'yes'
      test.exclude '*RemoteTMSClientTest*'
    end
    package(:jar)
  end
  
  desc "Task Management Service"
  define "tms-service" do
    libs = projects("deploy-api", "security", "security-ws-client", "tms-axis", "tms-common", "tms-client", "web-nutsNbolts", "dao-nutsNbolts"),
    APACHE_JPA, APACHE_COMMONS[:pool], AXIOM, AXIS2, JAXEN, SLF4J, SPRING[:core], STAX_API, XMLBEANS, DB_CONNECTOR.values
  
    compile.with libs
    test.with libs + [project("registry"), APACHE_DERBY, APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], CASTOR, EASY_B, LOG4J, DB_CONNECTOR.values, SUNMAIL, WSDL4J, WS_COMMONS_SCHEMA, WOODSTOX, XERCES]

    test.using :properties => 
      { 
        "org.intalio.tempo.configDirectory" => _("src/test/resources"),
        "jpa.config.file" => "jpa.properties"
      }

    # require live Axis2 instance
    unless ENV["LIVE"] == 'yes'
      test.exclude '*TMSAxis2RemoteTest*'
      test.exclude '*RemoteReassginTaskTest*'
      test.exclude "*ReassignTaskLiveTest*"
    end
    test.exclude '*TestUtils*'

    package(:jar)
    package(:aar).with :libs => 
        [ projects("deploy-api", "registry", "security", "security-ws-client", "security-ws-common", "tms-axis", "tms-common", "web-nutsNbolts", "dao-nutsNbolts"), APACHE_COMMONS[:pool], APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], APACHE_JPA, SLF4J, SPRING[:core] ] 
  end
  
  desc "Task Management Feeds"
  define "tms-feeds" do
    compile.with projects("tms-common", "ui-fw", "tms-axis", "security", "security-ws-client", "security-ws-common", "tms-client", "web-nutsNbolts"), 
    AXIOM, APACHE_ABDERA, APACHE_JPA, AXIS2, JETTY, LOG4J, SERVLET_API, SLF4J, SPRING[:core], XMLBEANS, WS_COMMONS_SCHEMA, WSDL4J
    package(:war)
  end 
  
  desc "User-Interface Framework"
  define "ui-fw" do
    libs = projects("security", "security-ws-client", "security-ws-common",
                    "tms-axis", "tms-client", "tms-common", "web-nutsNbolts"),
           APACHE_COMMONS[:io],
           APACHE_COMMONS[:httpclient],
           APACHE_COMMONS[:codec],
           APACHE_JPA,
           AXIOM, 
           AXIS2,  
           CSV,
           CASTOR,
           ICAL,
           INTALIO_STATS, 
           JSON,
           JSON_NAGGIT,
           JSP_API, 
           JSTL,
           LOG4J,
           SERVLET_API, 
           SPRING[:core], 
           SPRING[:webmvc],
           SLF4J, 
           STAX_API, 
           TAGLIBS, 
           WOODSTOX, 
           WSDL4J,
           WS_COMMONS_SCHEMA,
           XERCES, 
           XMLBEANS,
           CAS_CLIENT
    compile.with libs

    resources.filter.using "version" => VERSION_NUMBER
    package(:jar)
    package(:war).with(:libs=>libs).
      include("src/main/config/geronimo/1.0/*")
  end
  
  desc "User-Interface Framework Portlet"
  define "ui-fw-portlet" do
    libs = projects("security", "security-ws-client", "security-ws-common", "tms-axis", "tms-client", "tms-common", "ui-pluto", "ui-fw"),
           APACHE_JPA, APACHE_COMMONS[:io], APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], AXIOM, AXIS2, CAS_CLIENT, DOM4J, INTALIO_STATS, 
           JSON, JSP_API, JSTL, LOG4J, PLUTO, PORTLET_API, SERVLET_API, 
           SPRING[:core], SPRING[:webmvc], SPRING[:webmvc_portlet], SLF4J, STAX_API, TAGLIBS, WOODSTOX, WSDL4J, WS_COMMONS_SCHEMA, 
           XERCES, XMLBEANS
    compile.with libs

    resources.filter.using "version" => VERSION_NUMBER
    package(:war).with(:libs=>libs).
      include("src/main/config/geronimo/1.0/*")
  end
  
  desc "Customized pluto webapp"
  define "ui-pluto" do
  	libs = projects("security"), PLUTO, SERVLET_API, APACHE_COMMONS[:logging], CAS_CLIENT
  	compile.with libs
  	package(:jar)
    package(:war)
  end
  
  define "registry" do
    compile.with SLF4J
  	package(:jar)
  end
  
  desc "Workflow Deployment Service"
  define "wds-service" do |project|
    libs = [ projects("dao-nutsNbolts", "deploy-api", "registry", "security", "tms-client", "tms-axis", "tms-common", "web-nutsNbolts"), 
      AXIS2, AXIOM, APACHE_COMMONS[:io], APACHE_COMMONS[:httpclient], APACHE_COMMONS[:codec], APACHE_COMMONS[:pool], APACHE_JPA, DOM4J, JAXEN, LOG4J, SERVLET_API, SLF4J, SPRING[:core], STAX_API, WS_COMMONS_SCHEMA, WSDL4J, WOODSTOX, XERCES, XMLBEANS ]
          
    test_libs = libs + [EASY_B, INSTINCT, DB_CONNECTOR.values]
    compile.with test_libs
    compile { open_jpa_enhance }
 
    resources.filter.using "version" => VERSION_NUMBER

    task "package" => generate_sql([project], "workflow.deployment")
    
    package(:jar)
    package(:war).with :libs=>libs
  end

  define "web-nutsNbolts" do
    libs = project("security"), AXIS2, APACHE_COMMONS[:lang], INTALIO_STATS, JSON_NAGGIT, JSP_API, LOG4J, SERVLET_API, SLF4J, SPRING[:core], SPRING[:webmvc]
    test_libs = libs + [JUNIT, INSTINCT]
    compile.with test_libs
    package :jar
  end
  
  desc "XForms Manager"
  define "xforms-manager" do
	compile.with ORBEON_LIBS
    resources.filter.using "version" => VERSION_NUMBER
    package(:war).with :libs=> ORBEON_LIBS
  end
end
