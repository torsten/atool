# atool

I know its a stupid name...

atool improves otool -tV in the following ways:

* in addition to callls, atool also annotates
  - addresses of classes
  - addresses of objective-c methods
  - addresses of CFStrings with their values
* c++ symbols get decoded using c++filt for better reading
* resolves \_\_unnamed symbols using gdb

here is some example output:

<pre>
movl	0x0002e8b0,%eax ; [mainBundle]
movl	%eax,0x04(%esp)
movl	0x0002ef58,%eax ; NSBundle
movl	%eax,(%esp)
calll	0x0002d0a7	; symbol stub for: _objc_msgSend
movl	$0x0002b0ac,0x0c(%esp) ; "plist"
movl	$0x0002b0bc,0x08(%esp) ; "defaults"
movl	0x0002e8ac,%edx ; [pathForResource:ofType:]
movl	%edx,0x04(%esp)
movl	%eax,(%esp)
calll	0x0002d0a7	; symbol stub for: _objc_msgSend
</pre>

with just otool it would have looked like this:

<pre>
movl	0x0002e8b0,%eax
movl	%eax,0x04(%esp)
movl	0x0002ef58,%eax
movl	%eax,(%esp)
calll	0x0002d0a7	; symbol stub for: _objc_msgSend
movl	$0x0002b0ac,0x0c(%esp)
movl	$0x0002b0bc,0x08(%esp)
movl	0x0002e8ac,%edx
movl	%edx,0x04(%esp)
movl	%eax,(%esp)
calll	0x0002d0a7	; symbol stub for: _objc_msgSend
</pre>
