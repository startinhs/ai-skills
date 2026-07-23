package com.bixolon.sample;

import android.app.AlertDialog;
import android.content.ContentResolver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.Message;
import android.provider.MediaStore;
import android.support.v4.app.Fragment;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.UnsupportedEncodingException;
import java.nio.ByteBuffer;

public class UsbPeripheralFragment extends Fragment implements View.OnClickListener {
    AlertDialogFragment newFragment;
    String tag = "DialogCustomDevices";

    private TextView deviceMessagesTextView;

    private int REQUEST_CODE_ACTION_PICK = 1;
    private int deviceID = 10;
    byte[] data = null;

    public static UsbPeripheralFragment newInstance() {
        UsbPeripheralFragment fragment = new UsbPeripheralFragment();
        Bundle args = new Bundle();
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_usb_peripheral, container, false);

        view.findViewById(R.id.buttonSearchDevices).setOnClickListener(this);
        view.findViewById(R.id.buttonSendData).setOnClickListener(this);
        view.findViewById(R.id.buttonSetSerialSettings).setOnClickListener(this);
        view.findViewById(R.id.buttonGetSerialSettings).setOnClickListener(this);
        view.findViewById(R.id.buttonGetVidPid).setOnClickListener(this);
        view.findViewById(R.id.buttonGetSerialNumber).setOnClickListener(this);
        view.findViewById(R.id.buttonGetCustomUsbList).setOnClickListener(this);
        view.findViewById(R.id.buttonAddCustomUsbDevice).setOnClickListener(this);
        view.findViewById(R.id.buttonDelCustomUsbDevice).setOnClickListener(this);
        view.findViewById(R.id.buttonResetCustomUsbDevice).setOnClickListener(this);


        deviceMessagesTextView = view.findViewById(R.id.textViewDeviceMessages);
        deviceMessagesTextView.setMovementMethod(new ScrollingMovementMethod());
        deviceMessagesTextView.setVerticalScrollBarEnabled(true);

        return view;
    }


    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.buttonSearchDevices:
                byte[] devices = MainActivity.getPrinterInstance().searchUsbDevices();

                if (devices != null && devices.length > 0) {
                    String[] items = new String[devices.length];

                    for (int i = 0; i < devices.length; i++) {
                        items[i] = "" + devices[i];
                    }
                    AlertDialog dialog = new AlertDialog.Builder(getContext()).setTitle("Devices List").setItems(items, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                            String strID = items[which];
                            deviceID = Integer.parseInt(strID);
                            MainActivity.getPrinterInstance().readUsbPeripheralData(deviceID);
                        }
                    }).create();
                    dialog.show();
                }else{
                    setDeviceLog("Read Fail");
                }
                break;

            case R.id.buttonSendData:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showSendData, getContext(), deviceID);
                newFragment.show(getFragmentManager(), tag);

                break;
            case R.id.buttonSetSerialSettings:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showSetSerialData, getContext(), deviceID);
                newFragment.show(getFragmentManager(), tag);
                break;
            case R.id.buttonGetSerialSettings:
                data = MainActivity.getPrinterInstance().getSerialSettingData(deviceID);

                if (data != null && data.length > 1) {
                    String[] infos = new String[1];

                    String strInfo = "baudRate : " + getContext().getResources().getStringArray(R.array.baudrate)[data[0] & 0xff] + "\n";
                    strInfo += "dataBits : " + getContext().getResources().getStringArray(R.array.databits)[data[1] & 0xff]+ "\n";
                    strInfo += "stopBits : " + getContext().getResources().getStringArray(R.array.stopbits)[data[2] & 0xff]+ "\n";
                    strInfo += "parity : " + getContext().getResources().getStringArray(R.array.parity)[data[3] & 0xff]+ "\n";
                    strInfo += "flowControl : " +  getContext().getResources().getStringArray(R.array.flowcontrol)[data[4] & 0xff];

                    infos[0] = strInfo;

                    AlertDialog dialog = new AlertDialog.Builder(getContext()).setTitle("Devices List").setItems(infos, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                        }
                    }).create();
                }else{
                    setDeviceLog("Read Fail");
                }
                break;
            case R.id.buttonGetVidPid:
                data = MainActivity.getPrinterInstance().getVidPid(deviceID);

                if (data != null && data.length > 4) {
                    String[] infos = new String[data.length/4];

                    infos[0] = "VID : " + String.format("%02X", (data[1] & 0xff)) + String.format("%02X", (data[0] & 0xff)) + " / "
                     + "PID : " + String.format("%02X", (data[3] & 0xff)) + String.format("%02X", (data[2] & 0xff));

                    AlertDialog dialog = new AlertDialog.Builder(getContext()).setTitle("VID/PID(deviceID : " + deviceID + ")").setItems(infos, new DialogInterface.OnClickListener() {
                        public void onClick(DialogInterface dialog, int which) {
                        }
                    }).create();
                    dialog.show();
                }else{
                    setDeviceLog("Read Fail");
                }
                break;
            case R.id.buttonGetSerialNumber:
                data = MainActivity.getPrinterInstance().getSerialNumber(deviceID);

                if (data != null && data.length > 0) {
                    String[] infos = new String[1];

                    String strData = null;
                    try {
                        strData = new String(data, "UTF-8");
                        infos[0] = strData;

                        AlertDialog dialog = new AlertDialog.Builder(getContext()).setTitle("Serial Number(Device ID : " + deviceID + ")").setItems(infos, new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int which) {
                            }
                        }).create();
                        dialog.show();

                    } catch (UnsupportedEncodingException e) {
                        e.printStackTrace();
                    }
                }else{
                    setDeviceLog("Read Fail");
                }
                break;
            case R.id.buttonGetCustomUsbList:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showCustomDevice, getContext(), 1);
                newFragment.show(getFragmentManager(), tag);
                break;
            case R.id.buttonAddCustomUsbDevice:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showCustomDevice, getContext(), 2);
                newFragment.show(getFragmentManager(), tag);
                break;
            case R.id.buttonDelCustomUsbDevice:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showCustomDevice, getContext(), 3);
                newFragment.show(getFragmentManager(), tag);
                break;
            case R.id.buttonResetCustomUsbDevice:
                newFragment = AlertDialogFragment.newInstance(MainActivity.showCustomDevice, getContext(), 4);
                newFragment.show(getFragmentManager(), tag);
                break;
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_ACTION_PICK) {
            if (data != null) {
                Uri uri = data.getData();
                ContentResolver cr = getActivity().getContentResolver();
                Cursor c = cr.query(uri, new String[]{MediaStore.Images.Media.DATA}, null, null, null);
                if (c == null || c.getCount() == 0) {
                    return;
                }

                c.moveToFirst();
                int columnIndex = c.getColumnIndexOrThrow(MediaStore.Images.Media.DATA);
                String text = c.getString(columnIndex);

                int width = MainActivity.getPrinterInstance().getPrinterMaxWidth();
                if (MainActivity.getPrinterInstance().defineNvImage(text, 1, 200, 50)) {
                    MainActivity.getPrinterInstance().printNVImage(1);
                }
            }
        }
    }

    public void setDeviceLog(String data) {
        mHandler.obtainMessage(0, 0, 0, data).sendToTarget();
    }

    public final Handler mHandler = new Handler(new Handler.Callback() {
        @SuppressWarnings("unchecked")
        @Override
        public boolean handleMessage(Message msg) {
            switch (msg.what) {
                case 0:
                    deviceMessagesTextView.append((String) msg.obj + "\n");

                    Layout layout = deviceMessagesTextView.getLayout();
                    if (layout != null) {
                        int y = layout.getLineTop(
                                deviceMessagesTextView.getLineCount()) - deviceMessagesTextView.getHeight();
                        if (y > 0) {
                            deviceMessagesTextView.scrollTo(0, y);
                            deviceMessagesTextView.invalidate();
                        }
                    }
                    break;
            }
            return false;
        }
    });
}
