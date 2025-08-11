We need to integrate the button into OpenWrt firmware.

ssh root@openwrt.lan
^^^ this command works, and connects you to OpenWrt router. It's router that doesn't have a lot of packages installed, just standard OpenWrt. The router is LinkSys MR8300. ARM32 CPU, low memory, low hard drive. First let's explain what we need.

We need to interrupt Internet flow.

Imagine you're watching YouTube shorts, or TikToks, or other shit. You're wasting tons of time on it. We want to stop router every N minutes. By default it's gonna be 40 minutes. But needs to be configurable.

The way stop function works is:

When router device is turned on, we do 1) blink (button sequence: ON, OFF) 2)  double beep: high, and then immediately low. It means device is in active mode and can be used to control the router.

When router turns on, it starts 40 minute timer. Should be reliable, if the process is getting killed, shit will just stop working. So probably cron shit every minute.

After 39 minutes we do a high beep, and three single blink (ON, 0.5 second pause. OFF 0.5 second pause. ON 0.5 second pause OFF 0.5 second pause ON 0.5 second pause OFF). 30 seconds before repeat flashing, but without a beep. At 40 minute mark - double high beep and turn the red light ON.

Pretty much RED light is the indicator that there is no internet. You have to press Enter to have Internet. Enter is simulated by the button, so it acts like keyboard. So on router we need to add it as a keyboard.

In other words we need investigate now only, only investigate - do not implement:

1) if you can connect to the router, and if you see the button (I connected USB to the router)

2) if you can control the button - send commands. Commands from Ruby files we created in current directory work fine. When you do this, you can ask me what I see and what I hear.

3) if you can access keyboard (it's gonna be button keyboard - only one Enter) on the router. Again, I can hit the button physically, and you can tell me to do that, and you will be capturing it. There is no other devices connected to the router.

Your goal is to understand:

1) if we can solve the basic necessities - basic needs - since router is very limited. Now it's not connected to internet. Maybe I need to connect it, maybe I need to install packages. I don't know. I wanna understand what to install. I can update firmware on that router, install missing packages if needed.

2) I'm pretty sure we can't use Ruby, since there is no Ruby. We might want to use Golang, and compile binary - it's the worst case scenario. We can run binary on ARM32, but I want to avoid that, since toolchain isn't installed on the current machine (this one, not router). And router is minimalistic.

3) I want you to create a file called prd1-result.md with all the details and recommendations.


