import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('devices')
export class DeviceEntity {
  @PrimaryGeneratedColumn()
  device_id: number;

  @Column({ type: 'varchar', length: 128 })
  device_secret_hash: string;

  @Column({ type: 'varchar', length: 50, nullable: true, default: null })
  device_name: string;

  @Column({ type: 'json', nullable: true, default: null })
  device_finger_print: any;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
