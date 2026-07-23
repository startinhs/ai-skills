package com.bixolon.sample;

import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.support.v4.app.Fragment;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

public class DirectIOFragment extends Fragment implements View.OnClickListener {

    private static final byte[][] DATA = {
            {0x1d, 0x49, 0x41},
            {0x1d, 0x49, 0x43},
            {0x1d, 0x49, 0x42},
            {0x1d, 0x49, 0x45},
            {0x1d, 0x49, 0x44}, // S/N
            {0x1d, 0x49, 0x4A}, // P/N
    };

    private EditText editTextData;
    private TextView deviceMessagesTextView;

    private int command = 0;

    public static DirectIOFragment newInstance() {
        DirectIOFragment fragment = new DirectIOFragment();
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
        View view = inflater.inflate(R.layout.fragment_driect_io, container, false);

        view.findViewById(R.id.buttonDirectCommand).setOnClickListener(this);
        view.findViewById(R.id.buttonSendData).setOnClickListener(this);

        editTextData = view.findViewById(R.id.editTextData);

        deviceMessagesTextView = view.findViewById(R.id.textViewDeviceMessages);
        deviceMessagesTextView.setMovementMethod(new ScrollingMovementMethod());
        deviceMessagesTextView.setVerticalScrollBarEnabled(true);

        Spinner directCommand = view.findViewById(R.id.driectCommand);

        ArrayAdapter commandAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.directIO, android.R.layout.simple_spinner_dropdown_item);
        commandAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        directCommand.setAdapter(commandAdapter);
        directCommand.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                command = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        return view;
    }

    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.buttonDirectCommand:
                if (command == 6) {
                    // batter status : low, middle, high, full
                    MainActivity.getPrinterInstance().directIO(2, null);
                } else if (command == 7) {
                    // battery remaining capacity
                    MainActivity.getPrinterInstance().directIO(4, null);
                } else if (command == 8) {
                    // TPH
                    MainActivity.getPrinterInstance().directIO(5, null);
                } else {
                    MainActivity.getPrinterInstance().directIO(1, DATA[command]);
                }

                break;
            case R.id.buttonSendData:
                String data = editTextData.getText().toString();
                if (data == null || data.isEmpty()) {
                    break;
                }

                data = data.replaceAll(" ", "");
                data = data.replaceAll("\n", "");
                byte[] command = MainActivity.getPrinterInstance().StringToHex(data);

                if (command != null) {
                    MainActivity.getPrinterInstance().directIO(1, command);
                }

                break;
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
