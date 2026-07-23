package com.bixolon.sample;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.text.InputType;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.nio.ByteBuffer;
import java.util.ArrayList;

public class AlertDialogFragment extends DialogFragment {
    protected static Context mContext;
    protected static int nVaule;

    private final ArrayList<String> bondedDevices = new ArrayList<String>();
    private ArrayAdapter<String> arrayAdapter;

    public static int selectedDeviceType = 0;
    public static String strVID = "";
    public static String strPID = "";
    public static TextView textViewDeviceInfo;
    public static String title = "";

    public static int selectedBaudRate = 0;
    public static int selectedDataBits = 0;
    public static int selectedStopBits = 0;
    public static int selectedParity = 0;
    public static int selectedFlowControl = 0;

    public static AlertDialogFragment newInstance(int title, final Context context, int data) {
        AlertDialogFragment adf = new AlertDialogFragment();
        Bundle arg1 = new Bundle();
        arg1.putInt("title", title);
        mContext = context;
        nVaule = data;
        adf.setArguments(arg1);
        return adf;
    }

    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        int title = getArguments().getInt("title");

        switch (title) {
            case MainActivity.showSendData:
                return showSendData(mContext, nVaule);
            case MainActivity.showSetSerialData:
                return showSetSerialData(mContext, nVaule);
            case MainActivity.showCustomDevice:
                return showCustomDevice(mContext, nVaule);

            default:
                return null;

        }

    }

    private AlertDialog showSendData(final Context context, final int devId) {

        LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        final View layout = inflater.inflate(R.layout.dialog_direct_io_usb_peripheral, null);

        final EditText editTextData = (EditText) layout.findViewById(R.id.editTextData);

        return new AlertDialog.Builder(context).setView(layout).setTitle(title).setPositiveButton(context.getResources().getString(R.string.ok), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

                String data = editTextData.getText().toString();
                if (data != null && !data.isEmpty()) {
                    data = data.replaceAll(" ", "");
                    data = data.replaceAll("\n", "");

                    byte[] command = MainActivity.getPrinterInstance().StringToHex(data);


                    if (command != null) {
                        MainActivity.getPrinterInstance().readUsbPeripheralData(devId);
                        MainActivity.getPrinterInstance().sendUsbPeripheralData(devId, command);
                    }

                }

            }
        }).setNegativeButton(context.getResources().getString(R.string.cancel), new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {

            }
        }).create();
    }

    private AlertDialog showSetSerialData(final Context context, final int devId) {

        LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        final View layout = inflater.inflate(R.layout.dialog_set_serial, null);

        Spinner sp1 = (Spinner) layout.findViewById(R.id.spinnerBaudRate);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedBaudRate = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });

        Spinner sp2 = (Spinner) layout.findViewById(R.id.spinnerDataBits);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedDataBits = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });

        Spinner sp3 = (Spinner) layout.findViewById(R.id.spinnerStopBits);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedStopBits = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });

        Spinner sp4 = (Spinner) layout.findViewById(R.id.spinnerParity);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedParity = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });

        Spinner sp5 = (Spinner) layout.findViewById(R.id.spinnerFlowControl);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedFlowControl = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });


        return new AlertDialog.Builder(context).setView(layout).setTitle("Set Serial Info(Device ID : " + devId + ")").setPositiveButton(context.getResources().getString(R.string.ok), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

                MainActivity.getPrinterInstance().setSerialSettingData(devId, selectedBaudRate, selectedDataBits, selectedStopBits, selectedParity, selectedFlowControl);

            }
        }).setNegativeButton(context.getResources().getString(R.string.cancel), new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {

            }
        }).create();
    }

    private AlertDialog showCustomDevice(final Context context, final int mode) {

        LayoutInflater inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        final View layout = inflater.inflate(R.layout.dialog_custom_device, null);

        Spinner sp1 = (Spinner) layout.findViewById(R.id.spinnerDevType);
        sp1.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                // TODO Auto-generated method stub
                selectedDeviceType = position;
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
                // TODO Auto-generated method stub

            }
        });

        TextView textViewVid = (TextView) layout.findViewById(R.id.textViewVid);
        TextView textViewPid = (TextView) layout.findViewById(R.id.textViewPid);
        final EditText editTextVid = (EditText) layout.findViewById(R.id.editTextVid);
        final EditText editTextPid = (EditText) layout.findViewById(R.id.editTextPid);

        textViewDeviceInfo = (TextView) layout.findViewById(R.id.textViewDeviceInfo);

        switch (mode) {
            case 1:
                title = context.getResources().getString(R.string.get_device);
                textViewVid.setVisibility(View.GONE);
                textViewPid.setVisibility(View.GONE);
                editTextVid.setVisibility(View.GONE);
                editTextPid.setVisibility(View.GONE);
                break;
            case 2:
                title = context.getResources().getString(R.string.add_device);
                textViewVid.setVisibility(View.VISIBLE);

                textViewPid.setVisibility(View.VISIBLE);
                editTextVid.setVisibility(View.VISIBLE);
                editTextPid.setVisibility(View.VISIBLE);
                break;

            case 3:
                title = context.getResources().getString(R.string.del_device);
                textViewVid.setVisibility(View.VISIBLE);

                textViewVid.setVisibility(View.VISIBLE);
                textViewPid.setVisibility(View.VISIBLE);
                editTextVid.setVisibility(View.VISIBLE);
                editTextPid.setVisibility(View.VISIBLE);
                break;

            case 4:
                title = context.getResources().getString(R.string.reinit_device);
                textViewVid.setVisibility(View.VISIBLE);

                textViewVid.setVisibility(View.GONE);
                textViewPid.setVisibility(View.GONE);
                editTextVid.setVisibility(View.GONE);
                editTextPid.setVisibility(View.GONE);
                break;

            default:
                break;
        }

        return new AlertDialog.Builder(context).setView(layout).setTitle(title).setPositiveButton(context.getResources().getString(R.string.ok), new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {

                switch (mode) {
                    case 1:
                        byte[] data = MainActivity.getPrinterInstance().getCustomUsbLists(selectedDeviceType);
                        String[] infos = null;
                        if (data != null && data.length > 0) {
                            infos = new String[data.length/4];

                            for(int i = 0; i< infos.length; i++){
                                infos[i] = "VID : " + String.format("%02X", (data[1] & 0xff)) + String.format("%02X", (data[0] & 0xff)) + " / "
                                        + "PID : " + String.format("%02X", (data[3] & 0xff)) + String.format("%02X", (data[2] & 0xff));
                            }
                            textViewDeviceInfo.setText(infos.toString());
                        }
                        break;
                    case 2:
                        if (editTextVid.getText().toString().length() > 0) {
                            strVID = editTextVid.getText().toString();
                            if (strVID.length() == 4) {
                                if (editTextPid.getText().toString().length() > 0) {
                                    strPID = editTextPid.getText().toString();
                                    if (strPID.length() == 4) {

                                        ByteBuffer deviceBuf = ByteBuffer.allocate(2 + 2);

                                        String output = strVID.substring(0, 2);
                                        int decimal = Integer.parseInt(output, 16);
                                        deviceBuf.put((byte) decimal);

                                        output = strVID.substring(2, 4);
                                        decimal = Integer.parseInt(output, 16);
                                        deviceBuf.put((byte) decimal);

                                        output = strPID.substring(0, 2);
                                        decimal = Integer.parseInt(output, 16);
                                        deviceBuf.put((byte) decimal);

                                        output = strPID.substring(2, 4);
                                        decimal = Integer.parseInt(output, 16);
                                        deviceBuf.put((byte) decimal);


                                        MainActivity.getPrinterInstance().addCustomUsbDevice(selectedDeviceType, deviceBuf.get(0), deviceBuf.get(1), deviceBuf.get(2), deviceBuf.get(3));

                                    } else {
                                        Toast.makeText(context, "check the Device PID.", Toast.LENGTH_SHORT).show();
                                    }
                                } else {
                                    Toast.makeText(context, "check the Device PID.", Toast.LENGTH_SHORT).show();
                                }
                            } else {
                                Toast.makeText(context, "check the Device VID.", Toast.LENGTH_SHORT).show();
                            }

                        } else {
                            Toast.makeText(context, "check the Device VID.", Toast.LENGTH_SHORT).show();
                        }

                        break;
                    case 3:
                        if (editTextVid.getText().toString().length() > 0) {
                            strVID = editTextVid.getText().toString();
                            if (strVID.length() == 4) {
                                if (editTextPid.getText().toString().length() > 0) {
                                    strPID = editTextPid.getText().toString();
                                    if (strPID.length() == 4) {

                                        ByteBuffer deviceBuf = ByteBuffer.allocate(2 + 2);
                                        deviceBuf.put(new java.math.BigInteger(strVID.substring(0, 2), 16).toByteArray());
                                        deviceBuf.put(new java.math.BigInteger(strVID.substring(2, 4), 16).toByteArray());
                                        deviceBuf.put(new java.math.BigInteger(strPID.substring(0, 2), 16).toByteArray());
                                        deviceBuf.put(new java.math.BigInteger(strPID.substring(2, 4), 16).toByteArray());

                                        MainActivity.getPrinterInstance().delCustomUsbDevice(selectedDeviceType, deviceBuf.get(0), deviceBuf.get(1), deviceBuf.get(2), deviceBuf.get(3));

                                    } else {
                                        Toast.makeText(context, "check the Device PID.", Toast.LENGTH_SHORT).show();
                                    }
                                } else {
                                    Toast.makeText(context, "check the Device PID.", Toast.LENGTH_SHORT).show();
                                }
                            } else {
                                Toast.makeText(context, "check the Device VID.", Toast.LENGTH_SHORT).show();
                            }

                        } else {
                            Toast.makeText(context, "check the Device VID.", Toast.LENGTH_SHORT).show();
                        }
                        break;
                    case 4:
                        MainActivity.getPrinterInstance().resetCustomUsbDevice(selectedDeviceType);
                        break;

                    default:
                        break;
                }

            }
        }).setNegativeButton(context.getResources().getString(R.string.cancel), new DialogInterface.OnClickListener() {
            public void onClick(DialogInterface dialog, int which) {

            }
        }).create();
    }

}
