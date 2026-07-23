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

import com.bixolon.sample.PrinterControl.BixolonPrinter;

public class BarcodeFragment extends Fragment implements View.OnClickListener {

    private EditText editTextHeight;
    private EditText editTextWidth;
    private EditText editTextBarcodeData;
    private TextView deviceMessagesTextView;

    private int spinnerAlignment = 0;
    private int spinnerSymbology = 0;
    private int spinnerHri = 0;

    public static BarcodeFragment newInstance() {
        BarcodeFragment fragment = new BarcodeFragment();
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
        View view = inflater.inflate(R.layout.fragment_barcode, container, false);

        view.findViewById(R.id.buttonPrint).setOnClickListener(this);

        editTextHeight = view.findViewById(R.id.editTextHeight);
        editTextWidth = view.findViewById(R.id.editTextWidth);
        editTextBarcodeData = view.findViewById(R.id.editTextData);

        editTextHeight.setText("150");
        editTextWidth.setText("2");
        editTextBarcodeData.setText("012345678905");

        deviceMessagesTextView = view.findViewById(R.id.textViewDeviceMessages);
        deviceMessagesTextView.setMovementMethod(new ScrollingMovementMethod());
        deviceMessagesTextView.setVerticalScrollBarEnabled(true);

        Spinner barcodeSymbology = view.findViewById(R.id.barcodeSymbology);
        Spinner barcodeAlignment = view.findViewById(R.id.barcodeAlignment);
        Spinner barcodeHri = view.findViewById(R.id.barcodeHRI);

        ArrayAdapter symbologyAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.barcodeSymbology, android.R.layout.simple_spinner_dropdown_item);
        symbologyAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        barcodeSymbology.setAdapter(symbologyAdapter);
        barcodeSymbology.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                editTextHeight.setText("150");
                editTextWidth.setText("2");

                spinnerSymbology = position;
                switch (spinnerSymbology) {
                    case 0:
                        editTextBarcodeData.setText("012345678905");
                        break;
                    case 1:
                        editTextBarcodeData.setText("012345678905");
                        break;
                    case 2:
                        editTextBarcodeData.setText("47112346");
                        break;
                    case 3:
                        editTextBarcodeData.setText("4711234567899");
                        break;
                    case 4:
                        editTextBarcodeData.setText("1234567895");
                        break;
                    case 5:
                        editTextBarcodeData.setText("A1234567B");
                        break;
                    case 6:
                        editTextBarcodeData.setText("ANDY0123");
                        break;
                    case 7:
                        editTextBarcodeData.setText("12341555");
                        break;
                    case 8:
                        editTextBarcodeData.setText("12345");
                        break;
                    case 9:
                        editTextHeight.setText("3");
                        editTextWidth.setText("3");
                        editTextBarcodeData.setText("http://www.bixolon.com");
                        break;
                    case 10:
                        editTextBarcodeData.setText("http://www.bixolon.com");
                        break;
                    case 11:
                        editTextBarcodeData.setText("http://www.bixolon.com");
                        break;
                    case 12:
                        editTextBarcodeData.setText("http://www.bixolon.com");
                        break;
                    case 13:
                        editTextBarcodeData.setText("012345678905");
                        editTextWidth.setText("3");
                        editTextHeight.setText("3");
                        break;
                }
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        ArrayAdapter alignmentAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.Alignment, android.R.layout.simple_spinner_dropdown_item);
        alignmentAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        barcodeAlignment.setAdapter(alignmentAdapter);
        barcodeAlignment.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                spinnerAlignment = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        ArrayAdapter HRIAdapter = ArrayAdapter.createFromResource(view.getContext(), R.array.barcodeHRI, android.R.layout.simple_spinner_dropdown_item);
        HRIAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        barcodeHri.setAdapter(HRIAdapter);
        barcodeHri.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                spinnerHri = position;
            }

            public void onNothingSelected(AdapterView<?> parent) {
            }
        });

        return view;
    }

    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.buttonPrint:
                String data = editTextBarcodeData.getText().toString();
                int width = Integer.parseInt(editTextWidth.getText().toString());
                int height = Integer.parseInt(editTextHeight.getText().toString());
                int symbology = 0, alignment = 0, Hri = 0;

                switch (spinnerSymbology) {
                    case 0:
                        symbology = BixolonPrinter.BARCODE_TYPE_UPCA;
                        break;
                    case 1:
                        symbology = BixolonPrinter.BARCODE_TYPE_UPCE;
                        break;
                    case 2:
                        symbology = BixolonPrinter.BARCODE_TYPE_EAN8;
                        break;
                    case 3:
                        symbology = BixolonPrinter.BARCODE_TYPE_EAN13;
                        break;
                    case 4:
                        symbology = BixolonPrinter.BARCODE_TYPE_ITF;
                        break;
                    case 5:
                        symbology = BixolonPrinter.BARCODE_TYPE_Codabar;
                        break;
                    case 6:
                        symbology = BixolonPrinter.BARCODE_TYPE_Code39;
                        break;
                    case 7:
                        symbology = BixolonPrinter.BARCODE_TYPE_Code93;
                        break;
                    case 8:
                        symbology = BixolonPrinter.BARCODE_TYPE_Code128;
                        break;
                    case 9:
                        symbology = BixolonPrinter.BARCODE_TYPE_PDF417;
                        break;
                    case 10:
                        symbology = BixolonPrinter.BARCODE_TYPE_MAXICODE;
                        break;
                    case 11:
                        symbology = BixolonPrinter.BARCODE_TYPE_DATAMATRIX;
                        break;
                    case 12:
                        symbology = BixolonPrinter.BARCODE_TYPE_QRCODE;
                        break;
                    case 13:
                        symbology = BixolonPrinter.BARCODE_TYPE_EAN128;
                        break;
                }

                switch (spinnerAlignment) {
                    case 0:
                        alignment = BixolonPrinter.ALIGNMENT_LEFT;
                        break;
                    case 1:
                        alignment = BixolonPrinter.ALIGNMENT_CENTER;
                        break;
                    case 2:
                        alignment = BixolonPrinter.ALIGNMENT_RIGHT;
                        break;
                    default:
                        alignment = BixolonPrinter.ALIGNMENT_LEFT;
                        break;
                }

                switch (spinnerHri) {
                    case 0:
                        Hri = BixolonPrinter.BARCODE_HRI_NONE;
                        break;
                    case 1:
                        Hri = BixolonPrinter.BARCODE_HRI_ABOVE;
                        break;
                    case 2:
                        Hri = BixolonPrinter.BARCODE_HRI_BELOW;
                        break;
                }

                if (data.length() == 0) {
                    Toast.makeText(getContext(), "No barcode data!", Toast.LENGTH_SHORT).show();
                    break;
                }

                MainActivity.getPrinterInstance().printBarcode(data, symbology, width, height, alignment, Hri);

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
