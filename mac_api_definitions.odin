package main
import "core:c"
import NS "vendor:darwin/Foundation"

#assert(size_of(DRTrackCallbackProc) == size_of(rawptr))
#assert(size_of(c.long) == size_of(int))

CFTypeRef :: rawptr
CFIndex :: distinct c.long 
CharBoolean :: distinct c.uchar
OSStatus :: distinct u32 //TODO: should be i32 though???

CFArrayRef :: distinct rawptr

CFDictionaryRef :: distinct rawptr

CFNumberRef :: distinct rawptr

CFAllocatorRef :: distinct rawptr

CFStringRef :: distinct rawptr

CFBooleanRef :: distinct rawptr

CFRunLoopRef :: distinct rawptr

CFRunLoopSourceRef :: distinct rawptr

CFRunLoopMode :: distinct CFStringRef

CFDictionaryKeyCallBacks :: struct {
    version: CFIndex,
    retain: rawptr,
    release: rawptr,
    copyDescription: rawptr,
    equal: rawptr,
    hash: rawptr,
}
CFDictionaryValueCallBacks :: struct {
    version: CFIndex,
    retain: rawptr,
    release: rawptr,
    copyDescription: rawptr,
    equal: rawptr,
}
CFArrayCallBacks :: struct {
    version: CFIndex,
    retain: rawptr,
    release: rawptr,
    copyDescription: rawptr,
    equal: rawptr,
} 
CFNumberType :: enum(CFIndex) {
    /* Fixed-width types */
    kCFNumberSInt8Type = 1,
    kCFNumberSInt16Type = 2,
    kCFNumberSInt32Type = 3,
    kCFNumberSInt64Type = 4,
    kCFNumberFloat32Type = 5,
    kCFNumberFloat64Type = 6,	/* 64-bit IEEE 754 */
    /* Basic C types */
    kCFNumberCharType = 7,
    kCFNumberShortType = 8,
    kCFNumberIntType = 9,
    kCFNumberLongType = 10,
    kCFNumberLongLongType = 11,
    kCFNumberFloatType = 12,
    kCFNumberDoubleType = 13,
    /* Other */
    kCFNumberCFIndexType = 14,
    kCFNumberNSIntegerType = 15,
    kCFNumberCGFloatType = 16,
    kCFNumberMaxType = 16
}
CFStringEncoding :: enum(u32) {
    kCFStringEncodingMacRoman = 0,
    kCFStringEncodingWindowsLatin1 = 0x0500, /* ANSI codepage 1252 */
    kCFStringEncodingISOLatin1 = 0x0201, /* ISO 8859-1 */
    kCFStringEncodingNextStepLatin = 0x0B01, /* NextStep encoding*/
    kCFStringEncodingASCII = 0x0600, /* 0..127 (in creating CFString, values greater than 0x7F are treated as corresponding Unicode value) */
    kCFStringEncodingUnicode = 0x0100, /* kTextEncodingUnicodeDefault  + kTextEncodingDefaultFormat (aka kUnicode16BitFormat) */
    kCFStringEncodingUTF8 = 0x08000100, /* kTextEncodingUnicodeDefault + kUnicodeUTF8Format */
    kCFStringEncodingNonLossyASCII = 0x0BFF, /* 7bit Unicode variants used by Cocoa & Java */

    kCFStringEncodingUTF16 = 0x0100, /* kTextEncodingUnicodeDefault + kUnicodeUTF16Format (alias of kCFStringEncodingUnicode) */
    kCFStringEncodingUTF16BE = 0x10000100, /* kTextEncodingUnicodeDefault + kUnicodeUTF16BEFormat */
    kCFStringEncodingUTF16LE = 0x14000100, /* kTextEncodingUnicodeDefault + kUnicodeUTF16LEFormat */

    kCFStringEncodingUTF32 = 0x0c000100, /* kTextEncodingUnicodeDefault + kUnicodeUTF32Format */
    kCFStringEncodingUTF32BE = 0x18000100, /* kTextEncodingUnicodeDefault + kUnicodeUTF32BEFormat */
    kCFStringEncodingUTF32LE = 0x1c000100 /* kTextEncodingUnicodeDefault + kUnicodeUTF32LEFormat */
}
foreign import CoreFoundation "system:CoreFoundation.framework"
foreign CoreFoundation {
    //CFAllocator
    CFGetRetainCount :: proc "c" (cf: CFTypeRef) -> CFIndex ---
    CFRelease :: proc "c" (cf: CFTypeRef) ---

    //CFArray
    kCFTypeArrayCallBacks: CFArrayCallBacks
    CFArrayCreate :: proc "c" (allocator: CFAllocatorRef, 
        values: [^]CFTypeRef,  numValues: CFIndex, callBacks: ^CFArrayCallBacks) -> CFArrayRef ---
    CFArrayGetCount :: proc "c" (theArray: CFArrayRef) -> CFIndex ---
    CFArrayGetValueAtIndex :: proc "c" (theArray: CFArrayRef, idx: CFIndex) -> rawptr ---

    //CFDictionary
    kCFCopyStringDictionaryKeyCallBacks: CFDictionaryKeyCallBacks
    kCFTypeDictionaryValueCallBacks: CFDictionaryValueCallBacks
    CFDictionaryCreate :: proc "c" (allocator: CFAllocatorRef, 
        keys: [^]CFTypeRef, values: [^]CFTypeRef, 
        numValues: CFIndex, keyCallBacks: ^CFDictionaryKeyCallBacks, 
        valueCallBacks: ^CFDictionaryValueCallBacks) -> CFDictionaryRef ---
    CFDictionaryGetValue :: proc "c" (theDict: CFDictionaryRef, key: rawptr) -> rawptr ---
    
    //CFNumber
    CFNumberCreate :: proc "c" (allocator: CFAllocatorRef, theType: CFNumberType, valuePtr: rawptr) -> CFNumberRef ---
    CFNumberGetValue :: proc "c" (number: CFNumberRef, theType: CFNumberType, valuePtr: rawptr) -> CharBoolean ---

    //CFBoolean
    kCFBooleanTrue: CFBooleanRef
    kCFBooleanFalse: CFBooleanRef

    //CFString
    // -1 for less than, 0 for equals, 1 for greater than
    CFStringCompare :: proc "c" (theString1: CFStringRef, theString2: CFStringRef, compareOptions: CFIndex) -> CFIndex ---
    CFStringGetCString :: proc "c" (theString: CFStringRef, buffer: [^]byte,  
        bufferSize: CFIndex, encoding: CFStringEncoding) -> CharBoolean ---
    CFStringGetLength :: proc "c" (theString: CFStringRef) -> CFIndex ---
    CFStringGetMaximumSizeForEncoding :: proc "c" (length: CFIndex, encoding: CFStringEncoding) -> CFIndex ---
    CFCopyDescription :: proc "c" (cf: CFTypeRef) -> CFStringRef ---
    NSLog :: proc "c" (format: ^NS.String, #c_vararg  args: ..any) ---

    //CFRunLoop
    kCFRunLoopCommonModes: CFRunLoopMode 
    CFRunLoopGetCurrent :: proc "c" () -> CFRunLoopRef ---
    CFRunLoopAddSource :: proc "c" (r1: CFRunLoopRef, source: CFRunLoopSourceRef, mode: CFRunLoopMode) ---
    CFRunLoopRun :: proc "c" () ---
    CFRunLoopSourceInvalidate :: proc "c" (source: CFRunLoopSourceRef) ---
    CFRunLoopStop :: proc "c" (r1: CFRunLoopRef) ---

}

DRBurnRef :: distinct rawptr
DRDeviceRef :: distinct rawptr
DRTrackRef :: distinct rawptr
DRTrackMessage :: enum(u32) {
	kDRTrackMessagePreBurn				= 0x70726520, //'pre ',
	kDRTrackMessageProduceData			= 0x70726f64, //'prod',
	kDRTrackMessageVerificationStarting	= 0x76737472, //'vstr',
	kDRTrackMessageVerifyData			= 0x76726679, //'vrfy',
	kDRTrackMessageVerificationDone		= 0x76646f6e, //'vdon',
	kDRTrackMessagePostBurn				= 0x706f7374, //'post',
	kDRTrackMessageEstimateLength		= 0x65737469, //'esti',	/* added in 10.3 */
	kDRTrackMessageProducePreGap		= 0x70727072, //'prpr',	/* added in 10.3 */
	kDRTrackMessageVerifyPreGap			= 0x76727072, //'vrpr'	/* added in 10.4 */
}
DRTrackCallbackProc :: distinct proc "c" (track: DRTrackRef, message: DRTrackMessage, ioParam: rawptr) -> OSStatus
/*!
	@enum 		Block Sizes
	@discussion	Common block sizes for different types of track data.
	@constant	kDRBlockSizeAudio			Audio data.
	@constant	kDRBlockSizeMode1Data		Mode 1 data.
	@constant	kDRBlockSizeMode2Data		Mode 2 data. Photo CD and CD-i use this.
	@constant	kDRBlockSizeMode2Form1Data	Mode 2 Form 1 data.
	@constant	kDRBlockSizeMode2Form2Data	Mode 2 Form 2 data.
	@constant	kDRBlockSizeDVDData			DVD data.
*/	
kDRBlockSizeAudio			:= cfnum(2352)
kDRBlockSizeMode1Data		:= cfnum(2048)
kDRBlockSizeMode2Data		:= cfnum(2332)
kDRBlockSizeMode2Form1Data	:= cfnum(2048)
kDRBlockSizeMode2Form2Data	:= cfnum(2324)
kDRBlockSizeDVDData			:= cfnum(2048)
/*!
	@enum 		Block Types
	@discussion	Common block type values for types of track data.
	@constant	kDRBlockTypeAudio			Audio data.
	@constant	kDRBlockTypeMode1Data		Mode 1 data.
	@constant	kDRBlockTypeMode2Data		Mode 2 data. Photo CD and CD-i use this.
	@constant	kDRBlockTypeMode2Form1Data	Mode 2 Form 1 data.
	@constant	kDRBlockTypeMode2Form2Data	Mode 2 Form 2 data.
	@constant	kDRBlockTypeDVDData			DVD data.
*/
kDRBlockTypeAudio			:= cfnum(0)
kDRBlockTypeMode1Data		:= cfnum(8)
kDRBlockTypeMode2Data		:= cfnum(13)
kDRBlockTypeMode2Form1Data	:= cfnum(10)
kDRBlockTypeMode2Form2Data	:= cfnum(12)
kDRBlockTypeDVDData			:= cfnum(8)
/*!
	@enum 		Data Forms
	@discussion	Common data form values for types of track data.
	@constant	kDRDataFormAudio			Audio data.
	@constant	kDRDataFormMode1Data		Mode 1 data.
	@constant	kDRDataFormMode2Data		Mode 2 data. Photo CD and CD-i use this.
	@constant	kDRDataFormMode2Form1Data	Mode 2 Form 1 data.
	@constant	kDRDataFormMode2Form2Data	Mode 2 Form 2 data.
	@constant	kDRDataFormDVDData			DVD data.
*/	
kDRDataFormAudio			:= cfnum(0)
kDRDataFormMode1Data		:= cfnum(16)
kDRDataFormMode2Data		:= cfnum(32)
kDRDataFormMode2Form1Data	:= cfnum(32)
kDRDataFormMode2Form2Data	:= cfnum(32)
kDRDataFormDVDData			:= cfnum(16)
/*!
	@enum 		Track Modes
	@discussion	Common track mode values for types of track data.
	@constant	kDRTrackModeAudio			Audio data.
	@constant	kDRTrackMode1Data			Mode 1 data.
	@constant	kDRTrackMode2Data			Mode 2 data. Photo CD and CD-i use this.
	@constant	kDRTrackMode2Form1Data		Mode 2 Form 1 data.
	@constant	kDRTrackMode2Form2Data		Mode 2 Form 2 data.
	@constant	kDRTrackModeDVDData			DVD data.
*/
kDRTrackModeAudio		:= cfnum(0)
kDRTrackMode1Data		:= cfnum(4)
kDRTrackMode2Data		:= cfnum(4)
kDRTrackMode2Form1Data	:= cfnum(4)
kDRTrackMode2Form2Data	:= cfnum(4)
kDRTrackModeDVDData		:= cfnum(5)

/*!
	@enum 		Session Format
	@discussion	Common session format values for types of track data.
	@constant	kDRSessionFormatAudio		Audio data.
	@constant	kDRSessionFormatMode1Data	Mode 1 data.
	@constant	kDRSessionFormatCDI			CD-I disc.
	@constant	kDRSessionFormatCDXA		CD-ROM XA disc.
	@constant	kDRSessionFormatDVDData		DVD data.
*/
kDRSessionFormatAudio		:= cfnum(0)
kDRSessionFormatMode1Data	:= cfnum(0)
kDRSessionFormatCDI			:= cfnum(0x10)
kDRSessionFormatCDXA		:= cfnum(0x20)
kDRSessionFormatDVDData		:= cfnum(0)

DRNotificationCallback :: #type proc "c" (center: DRNotificationCenterRef, 
    observer: rawptr, name: CFStringRef, object: CFTypeRef, info: CFDictionaryRef)
DRNotificationCenterRef :: distinct rawptr

foreign import DiscRecording "system:DiscRecording.framework"
foreign DiscRecording {


    /*!
	@const		kDRTrackLengthKey
	@discussion	Required Key. This key corresponds to a CFNumber object containing the length of 
				the track data in blocks.
    */
    kDRTrackLengthKey: CFStringRef

    /*!
        @const		kDRBlockSizeKey
        @discussion	Required key. This key corresponds to a CFNumber object containing the size
                    of each block of the track. Common values are defined in the @link //apple_ref/c/tag/Block%32Sizes Block Sizes @/link
                    enumeration.
    */
    kDRBlockSizeKey: CFStringRef

    /*!
        @const		kDRBlockTypeKey
        @discussion	Required key. This key corresponds to a CFNumber object containing the type
                    of each block of the track. Common values are defined in the @link //apple_ref/c/tag/Block%32Types Block Types @/link
                    enumeration.
    */
    kDRBlockTypeKey: CFStringRef			

    /*!
        @const		kDRDataFormKey
        @discussion	Required key. This key corresponds to a CFNumber object containing the data format
                    of each block of the track. Common values are defined in the @link //apple_ref/c/tag/Data%32Forms Data Forms @/link
                    enumeration.
    */
    kDRDataFormKey: CFStringRef	

    /*!
        @const		kDRSessionFormatKey
        @discussion	Required key. This key corresponds to a CFNumber object containing the session format
                    of the track. Common values are defined in the @link //apple_ref/c/tag/Session%32Mode Session Mode @/link enumeration.
    */
    kDRSessionFormatKey: CFStringRef

    /*!
        @const		kDRTrackModeKey
        @discussion	Required key. This key corresponds to a CFNumber object containing the track mode
                    of the track. Common values are defined in the @link //apple_ref/c/tag/Track%32Modes Track Modes @/link enumeration.
    */
    kDRTrackModeKey: CFStringRef	
    /*!
	@const		kDRPreGapLengthKey
	@discussion	Optional key. This track property key corresponds to a CFNumber object containing the length in blocks of 
				empty space, or pregap, to be recorded before the track. If this key is not
				present the Disc Recording engine will assume a 2 second, or 150 block, pregap.
    */
    kDRPreGapLengthKey: CFStringRef

    /*!
        @const kDRStatusStateKey
        @abstract	The state of the burn or erase operation.
        @discussion	A key for the status dictionaries. The value of this key is a CFString object indicating 
                    the current state of the burn or erase operation.
    */
    kDRStatusStateKey: CFStringRef
    /*!
	@const kDRStatusStateNone
	@abstract	The burn or erase operation has not begun.
	@discussion	A value for the @link kDRStatusStateKey kDRStatusStateKey @/link dictionary key. This value indicates the
				burn or erase operation has not yet begun.
    */
    kDRStatusStateNone: CFStringRef

    /*!
        @const kDRStatusStatePreparing
        @abstract	The burn or erase operation is preparing to begin.
        @discussion	A value for the @link kDRStatusStateKey kDRStatusStateKey @/link dictionary key. This value indicates the
                    burn or erase operation is preparing to begin.
    */
    kDRStatusStatePreparing: CFStringRef

    /*!
        @const kDRStatusStateVerifying
        @abstract	The burn or erase operation is being verified.
        @discussion	A value for the @link kDRStatusStateKey kDRStatusStateKey @/link dictionary key. This value indicates the
                    operation is verifying what it did.
    */
	kDRStatusStateVerifying: CFStringRef

    /*!
        @const kDRStatusStateDone
        @abstract	The burn or erase operation finished successfully.
        @discussion	A value for the @link kDRStatusStateKey kDRStatusStateKey @/link dictionary key. This value indicates the
                    burn or erase operation finished and succeeded.
    */
    kDRStatusStateDone: CFStringRef

    /*!
        @const kDRStatusStateFailed
        @abstract	The burn or erase operation failed.
        @discussion	A value for the @link kDRStatusStateKey kDRStatusStateKey @/link dictionary key. This value indicates the
                    burn or erase operation finished but failed.
    */
    kDRStatusStateFailed: CFStringRef
    /*!
        @const		kDRTrackStartAddressKey
        @discussion	This key corresponds to a CFNumber object containing the Logical Block Address (LBA)
                    of the start address for the track.
    */
    kDRTrackStartAddressKey: CFStringRef
    /*!
    @const		kDRPreGapIsRequiredKey
    @discussion	Optional key. This track property key corresponds to a CFBoolean object indicating whether 
                the pregap listed for the track is required.  If this key is not present, 
                the track will behave as though the key were <tt>false</tt>.
                
                If this key's value is set to <tt>true</tt> and the device does
                not support the exact pregap length, the burn
                will fail with a return value of @link //apple_ref/c/econst/kDRDevicePregapLengthNotAvailableErr @/link.
                
                If this key's value is set to <tt>false</tt> and the device does
                not support the suggested pregap length, the engine
                will choose an alternate pregap length. 
    */
    kDRPreGapIsRequiredKey: CFStringRef
    /*!
        @const		kDRBurnStrategyKey
        @abstract	One or more suggested burn strategies.
        @discussion	This burn property key corresponds to a CFString object, or to a CFArray object containing
                    CFString objects, indicating the suggested burn strategy or strategies.  
                    If this key is not present, the burn engine picks an appropriate burn 
                    strategy automatically--so most clients do not need to specify a burn strategy.
                    
                    When more than one strategy is suggested, the burn engine attempts to
                    use the first strategy in the list which is available.  A burn strategy
                    will never be used if it cannot write the required data. For example, the 
                    track-at-once (TAO) strategy cannot write CD-Text.
                    
                    This presence of this key alone is just a suggestion--if the burn
                    engine cannot fulfill the request it will burn using whatever
                    strategy is available.  To convert the suggestion into a requirement, add the
                    @link kDRBurnStrategyIsRequiredKey kDRBurnStrategyIsRequiredKey @/link key with a value of <tt>true</tt>.
                    
                    Before using this key you should ensure that the device
                    supports the strategy or strategies requested. Do this by checking the
                    burn strategy keys in the device's write capabilities dictionary.
    */
    kDRBurnStrategyKey: CFStringRef
    /*!
        @const		kDRBurnStrategyIsRequiredKey
        @abstract	Flag indicating whether to attempt to enforce the specified burn strategies.
        @discussion	This burn property key corresponds to a CFBoolean object indicating whether the burn
                    strategy or strategies listed for the @link kDRBurnStrategyKey kDRBurnStrategyKey @/link key are
                    the only ones allowed.  If this key is not present, the burn will 
                    behave as though the key were <tt>false</tt>.
                    
                    If this key's value is set to <tt>true</tt> and the device does
                    not support any of the suggested burn strategies, the burn
                    will fail with a return value of @link //apple_ref/c/econst/kDRDeviceBurnStrategyNotAvailableErr kDRDeviceBurnStrategyNotAvailableErr @/link.
                    
                    If this key's value is set to <tt>false</tt> and the device does
                    not support any of the suggested burn strategies, the engine
                    will choose an alternate burn strategy. The burn strategy
                    used will provide an equivalent disc.
    */
    kDRBurnStrategyIsRequiredKey: CFStringRef
    /*!
        @const		kDRBurnStrategyCDSAO
        @abstract	A CFString object representing the session-at-once (SAO) burn strategy for CD.
    */
    kDRBurnStrategyCDSAO: CFStringRef

    /*!
        @const kDRStatusPercentCompleteKey
        @abstract	The burn or erase operation's percentage of completion.
        @discussion	A key for the status dictionaries. The value of this key is 
                    a CFNumber object containing the precentage of completion for the burn 
                    or erase operation, expressed as a foating point number from 0 to 1.
    */
    kDRStatusPercentCompleteKey: CFStringRef

    kDRErrorStatusKey: CFStringRef
    kDRErrorStatusErrorStringKey: CFStringRef
    kDRErrorStatusAdditionalSenseStringKey: CFStringRef
    kDRErrorStatusErrorKey: CFStringRef

    kDRBurnStatusChangedNotification: CFStringRef
    kDRTrackNumberKey: CFStringRef
    kDRBurnRequestedSpeedKey: CFStringRef 


    DRBurnCreate :: proc "c" (device: DRDeviceRef) -> DRBurnRef ---
   /*
    For a multisession burn, the layout must be a valid CFArray object containing 
	multiple CFArrays, each of which contains one or more valid DRTrack objects.

	For a single-session, multitrack burn, the layout must be a valid CFArray object
	containing one or more valid DRTrack objects.
	
    For a single-session, single-track burn, the layout must be a valid
	DRTrack object.
	*/
    DRBurnWriteLayout :: proc "c" (burn: DRBurnRef, layout: CFTypeRef) -> OSStatus ---

    DRCopyDeviceArray :: proc "c" () -> CFArrayRef ---
    DRDeviceEjectMedia :: proc "c" (device: DRDeviceRef) -> OSStatus ---

    DRTrackCreate :: proc "c" (properties: CFDictionaryRef, callback: DRTrackCallbackProc) -> DRTrackRef ---
    DRTrackGetProperties :: proc "c" (track: DRTrackRef) -> CFDictionaryRef ---
    DRBurnSetProperties :: proc "c" (burn: DRBurnRef, properties: CFDictionaryRef) ---

    DRNotificationCenterCreate :: proc "c" () -> DRNotificationCenterRef ---
    DRNotificationCenterAddObserver :: proc "c" (center: DRNotificationCenterRef, 
        observer: rawptr, callback: DRNotificationCallback, 
        name: CFStringRef, object: rawptr) ---
    DRNotificationCenterRemoveObserver :: proc "c" (center: DRNotificationCenterRef,
        observer: rawptr, name: CFStringRef, object: rawptr) ---

    DRBurnCopyStatus :: proc "c" (burn: DRBurnRef) -> CFDictionaryRef ---
    DRBurnGetProperties :: proc "c" (burn: DRBurnRef) -> CFDictionaryRef ---
    DRNotificationCenterCreateRunLoopSource :: proc "c" (center: DRNotificationCenterRef) -> CFRunLoopSourceRef ---
}
