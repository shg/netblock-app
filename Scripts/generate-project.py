from pathlib import Path
import plistlib
import os
root=Path.cwd()
def plist(path,data):
 (root/path).write_bytes(plistlib.dumps(data))
base={'CFBundleDevelopmentRegion':'en','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleName':'$(PRODUCT_NAME)','CFBundleShortVersionString':'1.0','CFBundleVersion':'2'}
plist('NetBlock/Info.plist',base|{'CFBundlePackageType':'APPL','CFBundleIconFile':'NetBlock','CFBundleVersion':'3','LSUIElement':True,'LSMinimumSystemVersion':'$(MACOSX_DEPLOYMENT_TARGET)','NSSystemExtensionUsageDescription':'NetBlock blocks connections to the domains you specify.'})
plist('FilterExtension/Info.plist',base|{'CFBundlePackageType':'SYSX','NSSystemExtensionUsageDescription':'NetBlock blocks connections to the domains you specify.','NetworkExtension':{'NEProviderClasses':{'com.apple.networkextension.filter-data':'$(PRODUCT_MODULE_NAME).FilterDataProvider'},'NEMachServiceName':'$(TeamIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)'}})
plist('NetBlock/NetBlock.entitlements',{'com.apple.security.application-groups':['$(TeamIdentifierPrefix)org.kakera.netblock.app'],'com.apple.developer.system-extension.install':True,'com.apple.developer.networking.networkextension':['content-filter-provider']})
plist('FilterExtension/FilterExtension.entitlements',{'com.apple.security.application-groups':['$(TeamIdentifierPrefix)org.kakera.netblock.app'],'com.apple.developer.networking.networkextension':['content-filter-provider'],'com.apple.security.app-sandbox':True,'com.apple.security.network.client':True})
plist('NetBlock/NetBlock.DeveloperID.entitlements',{'com.apple.security.application-groups':['$(TeamIdentifierPrefix)org.kakera.netblock.app'],'com.apple.developer.system-extension.install':True,'com.apple.developer.networking.networkextension':['content-filter-provider-systemextension']})
plist('FilterExtension/FilterExtension.DeveloperID.entitlements',{'com.apple.security.application-groups':['$(TeamIdentifierPrefix)org.kakera.netblock.app'],'com.apple.developer.networking.networkextension':['content-filter-provider-systemextension'],'com.apple.security.app-sandbox':True,'com.apple.security.network.client':True})
objects={}; i=0
def obj(isa, **fields):
 global i
 i+=1; key=f'{i:024X}'; objects[key]={'isa':isa}|fields; return key
class Raw(str): pass
def ref(x): return Raw(x)
def refs(xs): return [ref(x) for x in xs]
def file(path,typ): return obj('PBXFileReference',lastKnownFileType=typ,path=path,sourceTree='<group>')
iconfile=file('NetBlock/Assets/NetBlock.icns','image.icns')
appfiles=[file('NetBlock/NetBlockApp.swift','sourcecode.swift'),file('NetBlock/FilterController.swift','sourcecode.swift'),file('NetBlock/ProxySettings.swift','sourcecode.swift')]
shared=file('Shared/DomainRules.swift','sourcecode.swift'); extfile=file('FilterExtension/FilterDataProvider.swift','sourcecode.swift'); extmain=file('FilterExtension/main.swift','sourcecode.swift')
appProduct=obj('PBXFileReference',explicitFileType='wrapper.application',path='NetBlock.app',sourceTree='BUILT_PRODUCTS_DIR')
extProduct=obj('PBXFileReference',explicitFileType='wrapper.system-extension',path='org.kakera.netblock.app.filter.systemextension',sourceTree='BUILT_PRODUCTS_DIR')
products=obj('PBXGroup',children=refs([appProduct,extProduct]),name='Products',sourceTree='<group>')
extras=[file(p,'text.plist.xml') for p in ['NetBlock/Info.plist','NetBlock/NetBlock.entitlements','FilterExtension/Info.plist','FilterExtension/FilterExtension.entitlements']]
group=obj('PBXGroup',children=refs(appfiles+[shared,extfile,extmain,iconfile]+extras+[products]),sourceTree='<group>')
def sources(files): return obj('PBXSourcesBuildPhase',buildActionMask=2147483647,files=refs([obj('PBXBuildFile',fileRef=ref(f)) for f in files]),runOnlyForDeploymentPostprocessing=0)
def configs(settings):
 ids=[]
 for name in ['Debug','Release']:
  ids.append(obj('XCBuildConfiguration',buildSettings=settings|{'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O'},name=name))
 return obj('XCConfigurationList',buildConfigurations=refs(ids),defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
common={'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','ALWAYS_SEARCH_USER_PATHS':'NO','SWIFT_VERSION':'5.0','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':os.environ.get('NETBLOCK_TEAM_ID', ''),'ENABLE_HARDENED_RUNTIME':'YES','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/../Frameworks']}
extTarget=obj('PBXNativeTarget',buildConfigurationList=ref(configs(common|{'PRODUCT_NAME':'org.kakera.netblock.app.filter','PRODUCT_MODULE_NAME':'NetBlockFilter','PRODUCT_BUNDLE_IDENTIFIER':'org.kakera.netblock.app.filter','INFOPLIST_FILE':'FilterExtension/Info.plist','CODE_SIGN_ENTITLEMENTS':'FilterExtension/FilterExtension.entitlements','SKIP_INSTALL':'YES'})),buildPhases=refs([sources([extfile,extmain,shared])]),buildRules=[],dependencies=[],name='NetBlockFilter',productName='org.kakera.netblock.app.filter',productReference=ref(extProduct),productType='com.apple.product-type.system-extension')
projectId=f'{i+100:024X}'
proxy=obj('PBXContainerItemProxy',containerPortal=ref(projectId),proxyType=1,remoteGlobalIDString=ref(extTarget),remoteInfo='NetBlockFilter')
dep=obj('PBXTargetDependency',target=ref(extTarget),targetProxy=ref(proxy))
embed=obj('PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='$(CONTENTS_FOLDER_PATH)/Library/SystemExtensions',dstSubfolderSpec=16,files=refs([obj('PBXBuildFile',fileRef=ref(extProduct),settings={'ATTRIBUTES':['CodeSignOnCopy']})]),name='Embed System Extension',runOnlyForDeploymentPostprocessing=0)
appTarget=obj('PBXNativeTarget',buildConfigurationList=ref(configs(common|{'PRODUCT_NAME':'NetBlock','PRODUCT_BUNDLE_IDENTIFIER':'org.kakera.netblock.app','INFOPLIST_FILE':'NetBlock/Info.plist','CODE_SIGN_ENTITLEMENTS':'NetBlock/NetBlock.entitlements'})),buildPhases=refs([sources(appfiles+[shared]),obj('PBXResourcesBuildPhase',buildActionMask=2147483647,files=refs([obj('PBXBuildFile',fileRef=ref(iconfile))]),runOnlyForDeploymentPostprocessing=0),embed]),buildRules=[],dependencies=refs([dep]),name='NetBlock',productName='NetBlock',productReference=ref(appProduct),productType='com.apple.product-type.application')
objects[projectId]={'isa':'PBXProject','attributes':{'LastUpgradeCheck':'2630'},'buildConfigurationList':ref(configs({})),'compatibilityVersion':'Xcode 14.0','developmentRegion':'en','hasScannedForEncodings':0,'knownRegions':['en','Base'],'mainGroup':ref(group),'productRefGroup':ref(products),'projectDirPath':'','projectRoot':'','targets':refs([appTarget,extTarget])}
import json
def fmt(v):
 if isinstance(v,Raw):return v
 if isinstance(v,dict):return '{ '+ ' '.join(f'{k} = {fmt(x)};' for k,x in v.items())+' }'
 if isinstance(v,list):return '('+', '.join(fmt(x) for x in v)+');'[:-1]
 if isinstance(v,int):return str(v)
 return json.dumps(v)
(root/'NetBlock.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+fmt({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':ref(projectId)}))
